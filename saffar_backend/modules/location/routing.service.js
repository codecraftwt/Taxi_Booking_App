const axios = require("axios");
const { query } = require("../../database");

/**
 * Calculates Haversine distance in meters
 */
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth radius in meters
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Generates synthetic intermediate road waypoints when external routing services are unreachable or offline
 */
function generateRoadWaypoints(startLat, startLon, endLat, endLon, numSegments = 12) {
  const points = [];
  points.push({ latitude: Number(startLat.toFixed(6)), longitude: Number(startLon.toFixed(6)) });

  const dLat = endLat - startLat;
  const dLon = endLon - startLon;

  // Perpendicular vector for realistic road curves
  const perpLat = -dLon * 0.08;
  const perpLon = dLat * 0.08;

  for (let i = 1; i < numSegments; i++) {
    const t = i / numSegments;
    // Cubic smooth interpolation with alternating curve
    const curve = Math.sin(t * Math.PI) * (i % 2 === 0 ? 1 : -0.7);
    const lat = startLat + t * dLat + curve * perpLat;
    const lon = startLon + t * dLon + curve * perpLon;
    points.push({
      latitude: Number(lat.toFixed(6)),
      longitude: Number(lon.toFixed(6)),
    });
  }

  points.push({ latitude: Number(endLat.toFixed(6)), longitude: Number(endLon.toFixed(6)) });
  return points;
}

/**
 * Calculate road route between origin and destination
 */
async function calculateRoute(originLat, originLon, destLat, destLon, vehicleCategory = "Auto") {
  const oLat = parseFloat(originLat);
  const oLon = parseFloat(originLon);
  const dLat = parseFloat(destLat);
  const dLon = parseFloat(destLon);

  if (isNaN(oLat) || isNaN(oLon) || isNaN(dLat) || isNaN(dLon)) {
    throw new Error("Invalid coordinate parameters for route calculation.");
  }

  const directDistance = haversineDistance(oLat, oLon, dLat, dLon);

  // Road detour multiplier (city road network is approx 1.25x straight line)
  let roadDistanceMeters = Math.round(directDistance * 1.28);
  if (roadDistanceMeters < 500) roadDistanceMeters = 500;

  // Average city traffic speeds in km/h
  let avgSpeedKmh = 24.0;
  if (vehicleCategory.toLowerCase().includes("bike")) avgSpeedKmh = 30.0;
  else if (vehicleCategory.toLowerCase().includes("car") || vehicleCategory.toLowerCase().includes("sedan")) avgSpeedKmh = 22.0;

  let durationSeconds = Math.round((roadDistanceMeters / 1000 / avgSpeedKmh) * 3600);
  if (durationSeconds < 180) durationSeconds = 180; // Minimum 3 mins

  let points = [];
  let routeFoundFromApi = false;

  // 1. Attempt OSRM free routing service if online (with fast 1.8s timeout)
  try {
    const osrmUrl = `https://router.project-osrm.org/route/v1/driving/${oLon},${oLat};${dLon},${dLat}?overview=full&geometries=geojson`;
    const osrmRes = await axios.get(osrmUrl, { timeout: 1800 });
    if (osrmRes.data && osrmRes.data.routes && osrmRes.data.routes.length > 0) {
      const route = osrmRes.data.routes[0];
      roadDistanceMeters = Math.round(route.distance);
      durationSeconds = Math.round(route.duration);
      const coords = route.geometry.coordinates; // [lon, lat]
      points = coords.map(([lon, lat]) => ({
        latitude: Number(lat.toFixed(6)),
        longitude: Number(lon.toFixed(6)),
      }));
      routeFoundFromApi = true;
    }
  } catch (_) {
    // Graceful fallback to offline road model
  }

  // 2. If external API failed or timed out, use synthetic smooth road-network model
  if (!routeFoundFromApi || points.length === 0) {
    const segments = Math.max(8, Math.min(24, Math.round(directDistance / 400)));
    points = generateRoadWaypoints(oLat, oLon, dLat, dLon, segments);
  }

  // Compute bounding box
  let minLat = oLat, maxLat = oLat, minLon = oLon, maxLon = oLon;
  for (const p of points) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLon) minLon = p.longitude;
    if (p.longitude > maxLon) maxLon = p.longitude;
  }

  const distanceKm = Number((roadDistanceMeters / 1000).toFixed(2));
  const durationMins = Math.ceil(durationSeconds / 60);

  return {
    success: true,
    distance_meters: roadDistanceMeters,
    distance_km: distanceKm,
    duration_seconds: durationSeconds,
    duration_minutes: durationMins,
    duration_text: `${durationMins} mins`,
    points,
    bounds: {
      northeast: { latitude: maxLat, longitude: maxLon },
      southwest: { latitude: minLat, longitude: minLon },
    },
    source: routeFoundFromApi ? "osrm" : "internal_road_model",
  };
}

/**
 * Reverse geocode a latitude & longitude into a human-readable location
 */
async function reverseGeocode(latitude, longitude) {
  const lat = parseFloat(latitude);
  const lon = parseFloat(longitude);

  if (isNaN(lat) || isNaN(lon)) {
    throw new Error("Invalid coordinate parameters for reverse geocoding.");
  }

  // 1. Try local database for closest matched address within 100 meters
  try {
    const dbRes = await query(
      `SELECT place, street, lat, lon,
              (6371000 * acos(cos(radians($1)) * cos(radians(lat)) * cos(radians(lon) - radians($2)) + sin(radians($1)) * sin(radians(lat)))) AS dist
       FROM addresses
       WHERE lat IS NOT NULL AND lon IS NOT NULL
       ORDER BY dist ASC
       LIMIT 1;`,
      [lat, lon]
    );

    if (dbRes.rows.length > 0 && dbRes.rows[0].dist <= 150) {
      const match = dbRes.rows[0];
      return {
        success: true,
        address: `${match.place}, ${match.street}`,
        place: match.place,
        street: match.street,
        city: "Bengaluru",
        state: "Karnataka",
        postal_code: "560001",
        latitude: lat,
        longitude: lon,
        source: "database",
      };
    }
  } catch (_) {}

  // 2. Try Nominatim with fast 1.5s timeout
  try {
    const nomUrl = `https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lon}&zoom=18&addressdetails=1`;
    const nomRes = await axios.get(nomUrl, {
      timeout: 1500,
      headers: { "User-Agent": "SaffarTaxiBackend/1.0.0 (contact@saffar.app)" },
    });

    if (nomRes.data && nomRes.data.display_name) {
      const d = nomRes.data;
      const addr = d.address || {};
      const placeName = addr.road || addr.suburb || addr.neighbourhood || addr.amenity || "Current Location";
      const cityName = addr.city || addr.town || addr.county || "Bengaluru";
      const stateName = addr.state || "Karnataka";
      const postcode = addr.postcode || "";

      return {
        success: true,
        address: d.display_name,
        place: placeName,
        street: addr.road ? `${addr.road}, ${addr.suburb || cityName}` : placeName,
        city: cityName,
        state: stateName,
        postal_code: postcode,
        latitude: lat,
        longitude: lon,
        source: "nominatim",
      };
    }
  } catch (_) {}

  // 3. Fallback coordinates-based descriptor
  const latStr = lat.toFixed(4);
  const lonStr = lon.toFixed(4);
  return {
    success: true,
    address: `Location near ${latStr}, ${lonStr}`,
    place: `Pin (${latStr}, ${lonStr})`,
    street: `Location at ${latStr}, ${lonStr}`,
    city: "Location",
    state: "India",
    postal_code: "",
    latitude: lat,
    longitude: lon,
    source: "coordinates_fallback",
  };
}

/**
 * Forward geocode a human-entered query into places with GPS coordinates
 * Uses Photon (fuzzy search matching typos like 'ichalakaranji') + Nominatim OSM
 */
async function forwardGeocode(queryText, limit = 8, userLat = null, userLon = null) {
  if (!queryText || queryText.trim().length === 0) return [];
  const q = queryText.trim();
  const results = [];
  const seen = new Set();

  const uLat = userLat != null ? parseFloat(userLat) : null;
  const uLon = userLon != null ? parseFloat(userLon) : null;

  // 1. Photon (Komoot OSM geocoder - fast fuzzy search with typo tolerance and location bias)
  try {
    let photonUrl = `https://photon.komoot.io/api/?q=${encodeURIComponent(q)}&limit=${limit}`;
    if (uLat != null && uLon != null && !isNaN(uLat) && !isNaN(uLon)) {
      photonUrl += `&lat=${uLat}&lon=${uLon}`;
    }
    const res = await fetch(photonUrl, { signal: AbortSignal.timeout(3000) });
    if (res.ok) {
      const data = await res.json();
      if (data && data.features) {
        for (const f of data.features) {
          const props = f.properties || {};
          const coords = f.geometry?.coordinates; // [lon, lat]
          if (coords && coords.length >= 2) {
            const name = props.name || props.street || q;
            const subtitleParts = [
              props.street,
              props.district,
              props.city,
              props.state,
              props.country,
              props.postcode,
            ].filter(Boolean);
            const subtitle = subtitleParts.join(", ") || props.country || "India";
            const placeLat = Number(coords[1].toFixed(6));
            const placeLon = Number(coords[0].toFixed(6));
            const dedupeKey = `${name}_${placeLat.toFixed(3)}_${placeLon.toFixed(3)}`.toLowerCase();

            let distanceKmText = "4.5 km";
            let durationMinsNum = 15;
            if (uLat != null && uLon != null && !isNaN(uLat) && !isNaN(uLon)) {
              const directMeters = haversineDistance(uLat, uLon, placeLat, placeLon);
              const roadKm = (directMeters * 1.25) / 1000.0;
              distanceKmText = roadKm < 1.0 ? `${Math.round(roadKm * 1000)} m` : `${roadKm.toFixed(1)} km`;
              durationMinsNum = Math.max(3, Math.round(roadKm * 2.5));
            }

            if (!seen.has(dedupeKey)) {
              seen.add(dedupeKey);
              results.push({
                id: `geo_p_${props.osm_id || Math.random().toString(36).substring(2, 9)}`,
                place: name,
                street: subtitle,
                type: props.osm_value || "popular",
                distance_km: distanceKmText,
                duration_mins: durationMinsNum,
                lat: placeLat,
                lon: placeLon,
                source: "photon",
              });
            }
          }
        }
      }
    }
  } catch (_) {}

  // 2. Supplementary: Nominatim OSM search (with India country bias)
  if (results.length < limit) {
    try {
      const nomUrl = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(q)}&format=json&addressdetails=1&limit=${limit}&countrycodes=in`;
      const res = await fetch(nomUrl, {
        headers: { "User-Agent": "SaffarTaxiApp/1.0.0 (contact@saffar.app)" },
        signal: AbortSignal.timeout(3000),
      });
      if (res.ok) {
        const data = await res.json();
        if (Array.isArray(data)) {
          for (const item of data) {
            const lat = parseFloat(item.lat);
            const lon = parseFloat(item.lon);
            const addr = item.address || {};
            const mainName = item.name || addr.road || addr.suburb || addr.city || addr.town || q;
            const dedupeKey = `${mainName}_${lat.toFixed(3)}_${lon.toFixed(3)}`.toLowerCase();

            let distanceKmText = "5.0 km";
            let durationMinsNum = 16;
            if (uLat != null && uLon != null && !isNaN(uLat) && !isNaN(uLon)) {
              const directMeters = haversineDistance(uLat, uLon, lat, lon);
              const roadKm = (directMeters * 1.25) / 1000.0;
              distanceKmText = roadKm < 1.0 ? `${Math.round(roadKm * 1000)} m` : `${roadKm.toFixed(1)} km`;
              durationMinsNum = Math.max(3, Math.round(roadKm * 2.5));
            }

            if (!seen.has(dedupeKey)) {
              seen.add(dedupeKey);
              results.push({
                id: `geo_n_${item.osm_id || Math.random().toString(36).substring(2, 9)}`,
                place: mainName,
                street: item.display_name,
                type: item.type || "popular",
                distance_km: distanceKmText,
                duration_mins: durationMinsNum,
                lat: Number(lat.toFixed(6)),
                lon: Number(lon.toFixed(6)),
                source: "nominatim",
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  return results;
}

module.exports = {
  haversineDistance,
  generateRoadWaypoints,
  calculateRoute,
  reverseGeocode,
  forwardGeocode,
};

