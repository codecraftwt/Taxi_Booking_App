const axios = require("axios");
const bcrypt = require("bcrypt");
const { v4: uuidv4 } = require("uuid");
const Constant = require("../config/constants");
const Err = require("../config/error");
const { query } = require("../database");
const Helper = require("../utils/helper");

const getPreviousRidesOfUser = async (req, res) => {
  try {
    const userId = req.body?.user_id ?? req.query?.user_id;

    if (!userId) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: Err.message.EMPTY_PARAM,
        },
      });
    }

    const ridesRes = await query(
      `SELECT 
        r.id,
        r.start_time,
        r.end_time,
        r.cancelled,
        r.price,
        r.discount_price,
        json_build_object(
          'id', u.id,
          'name', u.name,
          'phone', u.phone,
          'email', u.email,
          'imageUrl', u.image_url
        ) as user,
        json_build_object(
          'id', d.id,
          'name', d.name,
          'phone', d.phone,
          'vehicle_name', d.vehicle_name,
          'vehicle_number', d.vehicle_number,
          'image_url', d.image_url,
          'active', d.active
        ) as driver,
        json_build_object(
          'id', sa.id,
          'place', sa.place,
          'street', sa.street,
          'state', sa.state,
          'country', sa.country,
          'lat', sa.lat,
          'lon', sa.lon,
          'pincode', sa.pincode
        ) as source_address,
        json_build_object(
          'id', da.id,
          'place', da.place,
          'street', da.street,
          'state', da.state,
          'country', da.country,
          'lat', da.lat,
          'lon', da.lon,
          'pincode', da.pincode
        ) as destination_address
      FROM rides r
      JOIN users u ON r.user_id = u.id
      JOIN drivers d ON r.driver_id = d.id
      JOIN addresses sa ON r.source_address_id = sa.id
      JOIN addresses da ON r.destination_address_id = da.id
      WHERE r.user_id = $1
      ORDER BY r.start_time DESC`,
      [userId]
    );

    return res.status(200).json({
      message: "All previous rides of the user fetched successfully.",
      previous_rides: ridesRes.rows,
    });
  } catch (error) {
    console.log(`Error in getPreviousRidesOfUser: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: Err.message.SERVER_ERROR,
      },
    });
  }
};

const addRideAndRideAddresses = async (req, res) => {
  try {
    const {
      user_id: userId,
      driver_id: driverId,
      source_address: sourceAddress,
      destination_address: destinationAddress,
      start_time: startTimeString,
      end_time: endTimeString,
      cancelled = false,
      price,
      discount_price: discountPrice = null,
      id: customId,
    } = req.body;

    if (
      userId === undefined ||
      driverId === undefined ||
      sourceAddress === undefined ||
      destinationAddress === undefined ||
      startTimeString === undefined ||
      price === undefined
    ) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: Err.message.EMPTY_PARAM,
        },
      });
    }

    const startTime = new Date(startTimeString);
    const endTime = endTimeString ? new Date(endTimeString) : null;

    const sourceAddressId = sourceAddress.id || uuidv4();
    await query(
      `INSERT INTO addresses (id, place, street, state, country, lat, lon, pincode)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (id) DO UPDATE SET street = EXCLUDED.street`,
      [
        sourceAddressId,
        sourceAddress.place,
        sourceAddress.street,
        sourceAddress.state,
        sourceAddress.country,
        sourceAddress.lat,
        sourceAddress.lon,
        sourceAddress.pincode,
      ]
    );

    const destinationAddressId = destinationAddress.id || uuidv4();
    await query(
      `INSERT INTO addresses (id, place, street, state, country, lat, lon, pincode)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (id) DO UPDATE SET street = EXCLUDED.street`,
      [
        destinationAddressId,
        destinationAddress.place,
        destinationAddress.street,
        destinationAddress.state,
        destinationAddress.country,
        destinationAddress.lat,
        destinationAddress.lon,
        destinationAddress.pincode,
      ]
    );

    const rideId = customId || uuidv4();
    await query(
      `INSERT INTO rides (id, user_id, driver_id, source_address_id, destination_address_id, start_time, end_time, cancelled, price, discount_price)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       ON CONFLICT (id) DO NOTHING`,
      [
        rideId,
        userId,
        driverId,
        sourceAddressId,
        destinationAddressId,
        startTime,
        endTime,
        cancelled,
        price,
        discountPrice,
      ]
    );

    return res.status(200).json({
      message: "Ride created successfully.",
    });
  } catch (error) {
    console.log(`Error in addRideAndRideAddresses: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: Err.message.SERVER_ERROR,
      },
    });
  }
};

const getPriceInfoAndCalculateRidePrice = async (req, res) => {
  try {
    const rideDistanceInKm = req.body?.distance_in_km ?? req.query?.distance_in_km;

    if (!rideDistanceInKm) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: Err.message.EMPTY_PARAM,
        },
      });
    }

    const priceRes = await query("SELECT * FROM prices LIMIT 1");
    let basePrice = 50.0;
    let pricePerKm = 15.0;

    if (priceRes.rows.length > 0) {
      basePrice = parseFloat(priceRes.rows[0].base_price);
      pricePerKm = parseFloat(priceRes.rows[0].price_per_km);
    } else {
      await query("INSERT INTO prices (base_price, price_per_km) VALUES ($1, $2)", [basePrice, pricePerKm]);
    }

    const dist = parseFloat(rideDistanceInKm);
    const totalPrice = basePrice + dist * pricePerKm;

    return res.json({
      total_price: totalPrice,
    });
  } catch (error) {
    console.log(`Error in getPriceInfoAndCalculateRidePrice: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: Err.message.SERVER_ERROR,
      },
    });
  }
};

const findRideDriver = async (req, res) => {
  try {
    const latitude = parseFloat(req.body?.latitude ?? req.query?.latitude);
    const longitude = parseFloat(req.body?.longitude ?? req.query?.longitude);
    const mapApiKey = req.body?.map_api_key ?? req.query?.map_api_key;

    if (isNaN(latitude) || isNaN(longitude)) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: Err.message.EMPTY_PARAM,
        },
      });
    }

    const changeLatitude = Math.random() <= 0.5;
    const sign = Math.random() <= 0.5 ? 1 : -1;
    const pointLatitude = latitude + (changeLatitude ? sign * 0.018 : 0);
    const pointLongitude = longitude + (!changeLatitude ? sign * 0.018 : 0);

    let driverSourceLatitude = pointLatitude;
    let driverSourceLongitude = pointLongitude;
    let driverDestinationLatitude = latitude;
    let driverDestinationLongitude = longitude;

    if (mapApiKey && mapApiKey !== "dummy_tomtom_api_key") {
      try {
        const response = await axios.get(
          `https://api.tomtom.com/routing/1/calculateRoute/${pointLatitude},${pointLongitude}:${latitude},${longitude}/json?key=${mapApiKey}`
        );
        const points = response.data["routes"][0]["legs"][0]["points"];
        driverSourceLatitude = Number.parseFloat(points[0]["latitude"]);
        driverSourceLongitude = Number.parseFloat(points[0]["longitude"]);
        driverDestinationLatitude = Number.parseFloat(points[points.length - 1]["latitude"]);
        driverDestinationLongitude = Number.parseFloat(points[points.length - 1]["longitude"]);
      } catch (tomtomErr) {
        console.log("TomTom routing fallback used (direct coordinates)");
      }
    }

    const driverRes = await query("SELECT * FROM drivers WHERE active = true LIMIT 1");
    let driver = driverRes.rows[0];

    if (!driver) {
      const index = Helper.getRandomInt(Constant.names.length);
      const name = Constant.names[index];
      const phone = Helper.generatePhone();
      const password = Date.now().toString();
      const vehicleName = Constant.vehicleNames[index];
      const vehicleNumber = Constant.vehicleNumbers[index];
      const hashedPassword = await bcrypt.hash(password, Constant.saltRounds);
      const id = uuidv4();

      const insertRes = await query(
        `INSERT INTO drivers (id, name, phone, password, vehicle_name, vehicle_number, active)
         VALUES ($1, $2, $3, $4, $5, $6, true) RETURNING *`,
        [id, name, phone, hashedPassword, vehicleName, vehicleNumber]
      );
      driver = insertRes.rows[0];
    }

    return res.json({
      driver: {
        id: driver.id,
        name: driver.name,
        phone: driver.phone,
        email: driver.email,
        vehicle_name: driver.vehicle_name,
        vehicle_number: driver.vehicle_number,
        image_url: driver.image_url,
        active: driver.active,
      },
      source_position: {
        latitude: driverSourceLatitude,
        longitude: driverSourceLongitude,
      },
      destination_position: {
        latitude: driverDestinationLatitude,
        longitude: driverDestinationLongitude,
      },
    });
  } catch (error) {
    console.log(`Error in findRideDriver: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: Err.message.SERVER_ERROR,
      },
    });
  }
};

module.exports = {
  getPreviousRidesOfUser,
  addRideAndRideAddresses,
  getPriceInfoAndCalculateRidePrice,
  findRideDriver,
};

