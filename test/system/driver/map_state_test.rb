require "application_system_test_case"

class Driver::MapStateTest < ApplicationSystemTestCase
  setup do
    @zone = create(:zone, name: "Test Zone", latitude: 47.64483, longitude: -122.54827)
    @route = create(:route, zone: @zone, name: "Test Route", latitude: 47.65, longitude: -122.55)
    @reservations = create_list(:reservation_with_coordinates, 5, route: @route, status: "Pending pickup")
  end

  test "map maintains position and zoom after marking tree as picked" do
    visit driver_reservations_map_path(route_id: @route.id)

    # Wait for map to load
    assert_selector "#map"
    sleep 2 # Allow Google Maps to initialize

    # Verify Stimulus controller is attached
    assert page.evaluate_script("document.querySelector('#map').dataset.controller === 'map-state'")

    # Get initial map center and zoom
    initial_center_lat = page.evaluate_script("window.currentMap.getCenter().lat()")
    initial_center_lng = page.evaluate_script("window.currentMap.getCenter().lng()")
    initial_zoom = page.evaluate_script("window.currentMap.getZoom()")

    # Pan and zoom the map to a new position
    page.execute_script("window.currentMap.setZoom(18)")
    page.execute_script("window.currentMap.setCenter(new google.maps.LatLng(47.66, -122.56))")
    sleep 1 # Allow map to settle and state to save

    # Get the new position
    new_center_lat = page.evaluate_script("window.currentMap.getCenter().lat()")
    new_center_lng = page.evaluate_script("window.currentMap.getCenter().lng()")
    new_zoom = page.evaluate_script("window.currentMap.getZoom()")

    # Verify position changed
    assert_not_equal initial_center_lat, new_center_lat
    assert_not_equal initial_center_lng, new_center_lng
    assert_not_equal initial_zoom, new_zoom

    # Click on a marker to open info window
    page.execute_script(<<~JS)
      var marker = Array.from(document.querySelectorAll('.gm-style-iw-d')).length === 0;
      var firstMarker = document.querySelector('.gm-advanced-marker');
      if (firstMarker) {
        firstMarker.click();
      }
    JS
    sleep 1

    # Mark tree as picked up
    within('.gm-style-iw') do
      accept_confirm do
        click_on 'Picked'
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

  test "map maintains position and zoom after marking tree as missing" do
    visit driver_reservations_map_path(route_id: @route.id)

    # Wait for map to load
    assert_selector "#map"
    sleep 2

    # Pan and zoom the map
    page.execute_script("window.currentMap.setZoom(17)")
    page.execute_script("window.currentMap.setCenter(new google.maps.LatLng(47.67, -122.57))")
    sleep 1

    # Get the position
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

  test "map maintains position after donation form submission" do
    visit driver_reservations_map_path(route_id: @route.id)

    # Wait for map to load
    assert_selector "#map"
    sleep 2

    # Pan and zoom
    page.execute_script("window.currentMap.setZoom(16)")
    page.execute_script("window.currentMap.setCenter(new google.maps.LatLng(47.68, -122.58))")
    sleep 1

    saved_center_lat = page.evaluate_script("window.currentMap.getCenter().lat()")
    saved_center_lng = page.evaluate_script("window.currentMap.getCenter().lng()")
    saved_zoom = page.evaluate_script("window.currentMap.getZoom()")

    # Click marker to open info window
    page.execute_script(<<~JS)
      var firstMarker = document.querySelector('.gm-advanced-marker');
      if (firstMarker) {
        firstMarker.click();
      }
    JS
    sleep 1

    # Fill donation form if present
    within('.gm-style-iw') do
      if has_selector?('input[name="collected"]')
        choose('collected_cash')
        fill_in 'collected_amount', with: '25.00'
        click_on 'Submit'
      end
    end

    # Wait for reload
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

  test "different routes maintain independent map states" do
    route2 = create(:route, zone: @zone, name: "Second Route", latitude: 47.70, longitude: -122.60)
    create_list(:reservation_with_coordinates, 3, route: route2)

    # Visit first route and set position
    visit driver_reservations_map_path(route_id: @route.id)
    assert_selector "#map"
    sleep 2

    page.execute_script("window.currentMap.setZoom(18)")
    page.execute_script("window.currentMap.setCenter(new google.maps.LatLng(47.65, -122.55))")
    sleep 1

    route1_center_lat = page.evaluate_script("window.currentMap.getCenter().lat()")
    route1_center_lng = page.evaluate_script("window.currentMap.getCenter().lng()")
    route1_zoom = page.evaluate_script("window.currentMap.getZoom()")

    # Visit second route and set different position
    visit driver_reservations_map_path(route_id: route2.id)
    assert_selector "#map"
    sleep 2

    page.execute_script("window.currentMap.setZoom(14)")
    page.execute_script("window.currentMap.setCenter(new google.maps.LatLng(47.70, -122.60))")
    sleep 1

    route2_center_lat = page.evaluate_script("window.currentMap.getCenter().lat()")
    route2_center_lng = page.evaluate_script("window.currentMap.getCenter().lng()")
    route2_zoom = page.evaluate_script("window.currentMap.getZoom()")

    # Go back to first route
    visit driver_reservations_map_path(route_id: @route.id)
    assert_selector "#map"
    sleep 2

    # Should restore first route's position
    restored_lat = page.evaluate_script("window.currentMap.getCenter().lat()")
    restored_lng = page.evaluate_script("window.currentMap.getCenter().lng()")
    restored_zoom = page.evaluate_script("window.currentMap.getZoom()")

    assert_in_delta route1_center_lat, restored_lat, 0.0001
    assert_in_delta route1_center_lng, restored_lng, 0.0001
    assert_equal route1_zoom, restored_zoom

    # Verify it's not the second route's position
    assert_not_in_delta route2_center_lat, restored_lat, 0.01
    assert_not_in_delta route2_center_lng, restored_lng, 0.01
  end

  test "map state persists across page refresh" do
    visit driver_reservations_map_path(route_id: @route.id)
    assert_selector "#map"
    sleep 2

    # Set custom position
    page.execute_script("window.currentMap.setZoom(19)")
    page.execute_script("window.currentMap.setCenter(new google.maps.LatLng(47.69, -122.59))")
    sleep 1

    saved_lat = page.evaluate_script("window.currentMap.getCenter().lat()")
    saved_lng = page.evaluate_script("window.currentMap.getCenter().lng()")
    saved_zoom = page.evaluate_script("window.currentMap.getZoom()")

    # Refresh the page
    page.evaluate_script("location.reload()")
    sleep 2
    assert_selector "#map"

    # Verify position restored after refresh
    restored_lat = page.evaluate_script("window.currentMap.getCenter().lat()")
    restored_lng = page.evaluate_script("window.currentMap.getCenter().lng()")
    restored_zoom = page.evaluate_script("window.currentMap.getZoom()")

    assert_in_delta saved_lat, restored_lat, 0.0001
    assert_in_delta saved_lng, restored_lng, 0.0001
    assert_equal saved_zoom, restored_zoom
  end

  test "map uses defaults when no saved state exists" do
    # Clear any existing session storage
    page.execute_script("sessionStorage.clear()")

    visit driver_reservations_map_path(route_id: @route.id)
    assert_selector "#map"
    sleep 2

    # Should use route's coordinates as default
    center_lat = page.evaluate_script("window.currentMap.getCenter().lat()")
    center_lng = page.evaluate_script("window.currentMap.getCenter().lng()")
    zoom = page.evaluate_script("window.currentMap.getZoom()")

    # Should be close to route's coordinates
    assert_in_delta @route.latitude, center_lat, 0.01
    assert_in_delta @route.longitude, center_lng, 0.01
    assert_equal 15, zoom # Default zoom for route
  end
end
