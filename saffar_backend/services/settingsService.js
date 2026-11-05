const { query } = require("../database");

const cache = new Map();
let lastFetchedAt = 0;
const CACHE_TTL_MS = 60 * 1000; // 1 minute in-memory cache

async function loadAllSettings() {
  const now = Date.now();
  if (cache.size > 0 && now - lastFetchedAt < CACHE_TTL_MS) {
    return cache;
  }

  try {
    const res = await query("SELECT key, value_json FROM app_settings;");
    cache.clear();
    for (const row of res.rows) {
      cache.set(row.key, row.value_json);
    }
    lastFetchedAt = now;
  } catch (err) {
    console.warn("[SETTINGS SERVICE] Error loading app_settings from DB:", err.message);
  }
  return cache;
}

async function getSetting(key, defaultValue = null) {
  await loadAllSettings();
  if (cache.has(key)) {
    return cache.get(key);
  }
  return defaultValue;
}

async function updateSetting(key, valueJson, description = null) {
  try {
    await query(`
      INSERT INTO app_settings (key, value_json, description, updated_at)
      VALUES ($1, $2, $3, (NOW() AT TIME ZONE 'UTC'))
      ON CONFLICT (key) DO UPDATE SET 
        value_json = EXCLUDED.value_json,
        description = COALESCE(EXCLUDED.description, app_settings.description),
        updated_at = (NOW() AT TIME ZONE 'UTC');
    `, [key, JSON.stringify(valueJson), description]);

    cache.set(key, valueJson);
    return true;
  } catch (err) {
    console.error(`[SETTINGS SERVICE] Error updating setting ${key}:`, err.message);
    throw err;
  }
}

// Convenient getter for matching configuration
async function getMatchingConfig() {
  return {
    initialRadiusKm: await getSetting("matching.initial_radius_km", 2),
    secondRadiusKm: await getSetting("matching.second_radius_km", 4),
    thirdRadiusKm: await getSetting("matching.third_radius_km", 6),
    maxRadiusKm: await getSetting("matching.max_radius_km", 10),
    batch1Size: await getSetting("matching.batch_1_size", 2),
    batch2Size: await getSetting("matching.batch_2_size", 3),
    batch3Size: await getSetting("matching.batch_3_size", 5),
    initialOfferTimeoutSeconds: await getSetting("matching.initial_offer_timeout_seconds", 12),
    subsequentOfferTimeoutSeconds: await getSetting("matching.subsequent_offer_timeout_seconds", 15),
    maxCandidatesPerBatch: await getSetting("matching.max_candidates_per_batch", 5),
    maxSearchDurationSeconds: await getSetting("matching.max_search_duration_seconds", 60),
    commissionRate: await getSetting("pricing.commission_rate", 0.15),
    staleTimeoutSeconds: await getSetting("location.stale_timeout_seconds", 180),
  };
}

module.exports = {
  loadAllSettings,
  getSetting,
  updateSetting,
  getMatchingConfig,
};

