const { v4: uuidv4 } = require("uuid");
const { query } = require("../../database");
const settingsService = require("../../services/settingsService");

function normalizeCategory(type) {
  if (!type) return "Auto";
  const lower = type.toLowerCase();
  if (lower.includes("bike")) return "Bike";
  if (lower.includes("auto")) return "Auto";
  if (lower.includes("car") || lower.includes("mini") || lower.includes("sedan") || lower.includes("suv")) return "Car";
  return type;
}

/**
 * Calculates authoritative upfront fare quote in integer minor units (Paise)
 */
async function calculateQuotedFare({ distanceKm, durationMinutes = null, category = "Auto", promoCode = null, isNight = false }) {
  const normCat = normalizeCategory(category);
  const catKey = normCat.toLowerCase();

  const baseFareMinor = await settingsService.getSetting(`pricing.base_fare_minor.${catKey}`, catKey === "bike" ? 3000 : catKey === "car" ? 8000 : 4500);
  const perKmMinor = await settingsService.getSetting(`pricing.per_km_minor.${catKey}`, catKey === "bike" ? 1000 : catKey === "car" ? 2200 : 1500);
  const perMinMinor = await settingsService.getSetting(`pricing.per_min_minor.${catKey}`, catKey === "bike" ? 150 : catKey === "car" ? 300 : 200);
  const minFareMinor = await settingsService.getSetting(`pricing.min_fare_minor.${catKey}`, catKey === "bike" ? 4000 : catKey === "car" ? 10000 : 5500);
  const commissionRate = await settingsService.getSetting("pricing.commission_rate", 0.15);

  const distKm = Math.max(0.5, parseFloat(distanceKm) || 1.0);
  const estDurationMin = durationMinutes ? parseInt(durationMinutes, 10) : Math.max(1, Math.round(distKm * 2.5));

  const distanceFareMinor = Math.round(distKm * perKmMinor);
  const timeFareMinor = Math.round(estDurationMin * perMinMinor);

  // Surcharges (e.g. night surge 1.15x)
  let subtotalMinor = baseFareMinor + distanceFareMinor + timeFareMinor;
  let nightSurchargeMinor = 0;
  if (isNight) {
    nightSurchargeMinor = Math.round(subtotalMinor * 0.15);
    subtotalMinor += nightSurchargeMinor;
  }

  // Enforce minimum fare
  let grossFareMinor = Math.max(minFareMinor, subtotalMinor);

  // Discount / Promo
  let discountMinor = 0;
  if (promoCode && promoCode.toUpperCase() === "SAVE30") {
    discountMinor = Math.min(5000, Math.round(grossFareMinor * 0.20)); // 20% capped at ₹50 (5000 paise)
  }

  const finalQuotedMinor = Math.max(minFareMinor, grossFareMinor - discountMinor);
  const platformFeeMinor = Math.round(finalQuotedMinor * commissionRate);
  const driverNetMinor = finalQuotedMinor - platformFeeMinor;

  return {
    category: normCat,
    distanceKm: distKm,
    durationMinutes: estDurationMin,
    currency: "INR",
    minorUnits: {
      baseFare: baseFareMinor,
      distanceFare: distanceFareMinor,
      timeFare: timeFareMinor,
      nightSurcharge: nightSurchargeMinor,
      minimumFare: minFareMinor,
      grossFare: grossFareMinor,
      discount: discountMinor,
      quotedTotalFare: finalQuotedMinor,
      platformFee: platformFeeMinor,
      driverNet: driverNetMinor,
    },
    display: {
      quotedFare: finalQuotedMinor / 100,
      discountedFare: (finalQuotedMinor - discountMinor) / 100,
      formattedFare: `₹${(finalQuotedMinor / 100).toFixed(2)}`,
    },
  };
}

/**
 * Calculates authoritative final fare upon trip completion including actual distance, time, and waiting charges
 */
async function calculateFinalFare({
  rideId,
  category = "Auto",
  actualDistanceKm = 8.4,
  actualDurationMinutes = 22,
  waitingMinutes = 0,
  tollChargesMinor = 0,
  tipMinor = 0,
  promoCode = null,
}) {
  const normCat = normalizeCategory(category);
  const catKey = normCat.toLowerCase();

  const baseFareMinor = await settingsService.getSetting(`pricing.base_fare_minor.${catKey}`, catKey === "bike" ? 3000 : catKey === "car" ? 8000 : 4500);
  const perKmMinor = await settingsService.getSetting(`pricing.per_km_minor.${catKey}`, catKey === "bike" ? 1000 : catKey === "car" ? 2200 : 1500);
  const perMinMinor = await settingsService.getSetting(`pricing.per_min_minor.${catKey}`, catKey === "bike" ? 150 : catKey === "car" ? 300 : 200);
  const minFareMinor = await settingsService.getSetting(`pricing.min_fare_minor.${catKey}`, catKey === "bike" ? 4000 : catKey === "car" ? 10000 : 5500);
  const commissionRate = await settingsService.getSetting("pricing.commission_rate", 0.15);

  const distKm = Math.max(0.5, parseFloat(actualDistanceKm));
  const durMin = Math.max(1, parseInt(actualDurationMinutes, 10));

  const distanceFareMinor = Math.round(distKm * perKmMinor);
  const timeFareMinor = Math.round(durMin * perMinMinor);

  // Waiting charges (free first 3 minutes, then ₹2.00 / min = 200 paise/min)
  let waitingChargesMinor = 0;
  if (waitingMinutes > 3) {
    waitingChargesMinor = Math.round((waitingMinutes - 3) * 200);
  }

  let subtotalMinor = baseFareMinor + distanceFareMinor + timeFareMinor + waitingChargesMinor + tollChargesMinor;
  let grossFareMinor = Math.max(minFareMinor, subtotalMinor);

  let discountMinor = 0;
  if (promoCode && promoCode.toUpperCase() === "SAVE30") {
    discountMinor = Math.min(5000, Math.round(grossFareMinor * 0.20));
  }

  const fareBeforeTip = Math.max(minFareMinor, grossFareMinor - discountMinor);
  const platformFeeMinor = Math.round(fareBeforeTip * commissionRate);
  const driverNetMinor = (fareBeforeTip - platformFeeMinor) + tipMinor;
  const finalTotalMinor = fareBeforeTip + tipMinor;

  return {
    category: normCat,
    distanceKm: distKm,
    durationMinutes: durMin,
    waitingMinutes,
    currency: "INR",
    breakdownMinor: {
      baseFareMinor,
      distanceFareMinor,
      timeFareMinor,
      waitingChargesMinor,
      tollChargesMinor,
      minimumFareMinor: minFareMinor,
      discountMinor,
      tipMinor,
      grossFareMinor,
      totalFareMinor: finalTotalMinor,
      platformFeeMinor,
      driverNetEarningsMinor: driverNetMinor,
    },
    display: {
      finalFare: finalTotalMinor / 100,
      formattedFare: `₹${(finalTotalMinor / 100).toFixed(2)}`,
      driverEarnings: driverNetMinor / 100,
      platformCommission: platformFeeMinor / 100,
    },
  };
}

/**
 * Calculates cancellation fee based on trip progress
 */
function calculateCancellationFee({ cancelledBy, minutesSinceAcceptance, isDriverArrived }) {
  if (cancelledBy === "driver") {
    return { cancellationFeeMinor: 0, reason: "No fee for passenger when driver cancels" };
  }
  // Passenger cancels:
  if (isDriverArrived || minutesSinceAcceptance > 3) {
    return { cancellationFeeMinor: 3000, reason: "Cancellation fee applied (cancelled >3 mins after accept or after arrival)" };
  }
  return { cancellationFeeMinor: 0, reason: "Free cancellation within grace period" };
}

module.exports = {
  calculateQuotedFare,
  calculateFinalFare,
  calculateCancellationFee,
  normalizeCategory,
};
