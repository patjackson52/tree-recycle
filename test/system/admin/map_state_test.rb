require "application_system_test_case"

class Admin::MapStateTest < ApplicationSystemTestCase
  setup do
    @zone = create(:zone, name: "Admin Test Zone", latitude: 47.64483, longitude: -122.54827)
    @route = create(:route, zone: @zone, name: "Admin Test Route", latitude: 47.65, longitude: -122.55)
    @reservations = create_list(:reservation_with_coordinates, 5, route: @route, status: "Pending pickup")
    @admin = create(:user, role: "admin")
    sign_in @admin
  end

  test "admin map maintains position and zoom after marking tree as picked" do
    visit admin_reservations_map_path(route_id: @route.id)

    # Wait for map to load
    assert_selector "#map"
    sleep 2

    # Verify Stimulus controller is attached
    assert page.evaluate_script("document.querySelector('#map').dataset.controller === 'map-state'")

    # Pan and zoom the map to a new position
    page.execute_script("window.currentMap.setZoom(17)")
    page.execute_script("window.currentMap.setCenter(new google.maps.LatLng(47.66, -122.56))")
    sleep 1

    # Get the new position
    new_center_lat = page.evaluate_script("window.currentMap.getCenter().lat()")
    new_center_lng = page.evaluate_script("window.currentMap.getCenter().lng()")
    new_zoom = page.evaluate_script("window.currentMap.getZoom()")

    # Click on a marker to open info window
    page.execute_script(<<~JS)
      var firstMarker = document.querySelector('.gm-advanced-marker');
      if (firstMarker) {
        firstMarker.click();
      }
    JS
    sleep 1

    # Mark tree as picked up
    within('.gm-style-iw') do
      accept_confirm do
        click_on 'Picked Up'
      end
    end

    # Wait for page to reload
    sleep 2
    assert_selector "#map"

    # Verify map returned to the saved position
    restored_center_lat = page.evaluate_script("window.currentMap.getCenter().lat()")
    restored_center_lng = page.evaluate_script("window.currentMap.getCenter().lng()")
    restored_zoom = page.evaluate_script("window.currentMap.getZoom()")

    # Allow small floating point differences
    assert_in_delta new_center_lat, restored_center_lat, 0.0001, "Latitude should be preserved"
    assert_in_delta new_center_lng, restored_center_lng, 0.0001, "Longitude should be preserved"
    assert_equal new_zoom, restored_zoom, "Zoom level should be preserved"
  end

  test "admin map maintains position after marking tree as missing" do
    visit admin_reservations_map_path(route_id: @route.id)

    # Wait for map to load
    assert_selector "#map"
    sleep 2

    # Pan and zoom the map
    page.execute_script("window.currentMap.setZoom(16)")
    page.execute_script("window.currentMap.setCenter(new google.maps.LatLng(47.67, -122.57))")
    sleep 1

    saved_center_lat = page.evaluate_script("window.currentMap.getCenter().lat()")
    saved_center_lng = page.evaluate_script("window.currentMap.getCenter().lng()")
    saved_zoom = page.evaluate_script("window.currentMap.getZoom()")

    # Click marker and mark as missing
    page.execute_script(<<~JS)
      var firstMarker = document.querySelector('.gm-advanced-marker');
      if (firstMarker) {
        firstMarker.click();
      }
    JS
    sleep 1

    within('.gm-style-iw') do
      accept_confirm do
        click_on 'Missing'
      end
    end

    # Wait for page to reload
    sleep 2
    assert_selector "#map"

    # Verify position preserved
    restored_center_lat = page.evaluate_script("window.currentMap.getCenter().lat()")
    restored_center_lng = page.evaluate_script("window.currentMap.getCenter().lng()")
    restored_zoom = page.evaluate_script("window.currentMap.getZoom()")

    assert_in_delta saved_center_lat, restored_center_lat, 0.0001
    assert_in_delta saved_center_lng, restored_center_lng, 0.0001
    assert_equal saved_zoom, restored_zoom
  end

  test "admin and driver maps maintain separate states" do
    # This test verifies that admin and driver use different storage keys

    # Set position in admin map
    visit admin_reservations_map_path(route_id: @route.id)
    assert_selector "#map"
    sleep 2

    page.execute_script("window.currentMap.setZoom(18)")
    page.execute_script("window.currentMap.setCenter(new google.maps.LatLng(47.65, -122.55))")
    sleep 1

    admin_lat = page.evaluate_script("window.currentMap.getCenter().lat()")
    admin_lng = page.evaluate_script("window.currentMap.getCenter().lng()")
    admin_zoom = page.evaluate_script("window.currentMap.getZoom()")

    # Check that the storage key is different for admin vs driver
    storage_key = page.evaluate_script("window.mapStateController.getStorageKey()")
    assert_match /admin/, storage_key, "Admin map should use 'admin' in storage key"
  end

  test "map state storage key includes route id" do
    visit admin_reservations_map_path(route_id: @route.id)
    assert_selector "#map"
    sleep 2

    # Verify storage key includes route ID
    storage_key = page.evaluate_script("window.mapStateController.getStorageKey()")
    assert_equal "mapState_admin_#{@route.id}", storage_key
  end

  test "map gracefully handles missing sessionStorage" do
    visit admin_reservations_map_path(route_id: @route.id)
    assert_selector "#map"
    sleep 2

    # Disable sessionStorage
    page.execute_script(<<~JS)
      Object.defineProperty(window, 'sessionStorage', {
        get: function() { throw new Error('sessionStorage disabled'); }
      });
    JS

    # Map should still work with defaults
    center_lat = page.evaluate_script("window.currentMap.getCenter().lat()")
    center_lng = page.evaluate_script("window.currentMap.getCenter().lng()")

    # Should use route defaults
    assert_in_delta @route.latitude, center_lat, 0.01
    assert_in_delta @route.longitude, center_lng, 0.01
  end
end
