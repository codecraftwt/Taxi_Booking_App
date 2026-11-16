const express = require("express");
const { verifyAdminAuth, requireRoles } = require("../../middlewares/admin_auth_middleware");
const {
  adminAuth,
  adminDashboard,
  adminDriver,
  adminDocument,
  adminLiveTracking,
  adminFare,
  adminRide,
  adminFinance,
  adminCustomer,
  adminAudit,
} = require("../../controllers/admin");

const router = express.Router();

// 1. Authentication
router.post("/auth/login", adminAuth.adminLogin);
router.get("/auth/me", verifyAdminAuth, adminAuth.getAdminProfile);
router.post("/auth/change-password", verifyAdminAuth, adminAuth.changeAdminPassword);

// 2. Main Dashboard Metrics
router.get("/dashboard/stats", verifyAdminAuth, adminDashboard.getDashboardStats);

// 3. Driver Management
router.delete("/drivers/purge-all", verifyAdminAuth, adminDriver.deleteAllDrivers);
router.get("/drivers", verifyAdminAuth, adminDriver.getDrivers);
router.get("/drivers/:driverId", verifyAdminAuth, adminDriver.getDriverDetails);
router.patch("/drivers/:driverId/status", verifyAdminAuth, adminDriver.updateDriverStatus);
router.put("/drivers/:driverId", verifyAdminAuth, adminDriver.updateDriverDetails);
router.delete("/drivers/:driverId", verifyAdminAuth, adminDriver.deleteDriver);

// 4. Document Verification
router.get("/documents", verifyAdminAuth, adminDocument.getPendingDocuments);
router.post("/documents/:documentId/verify", verifyAdminAuth, adminDocument.verifyDocument);

// 5. Live Tracking
router.get("/tracking/live", verifyAdminAuth, adminLiveTracking.getLiveDrivers);

// 6. Fare & Pricing Management
router.get("/fares", verifyAdminAuth, adminFare.getFareConfigs);
router.put("/fares/:category", verifyAdminAuth, requireRoles("super_admin", "operations_manager"), adminFare.updateFareConfig);

// 7. Ride Management
router.get("/rides", verifyAdminAuth, adminRide.getRides);
router.get("/rides/:rideId", verifyAdminAuth, adminRide.getRideDetails);
router.post("/rides/:rideId/cancel", verifyAdminAuth, adminRide.cancelRideByAdmin);

// 8. Finance & Settlements
router.get("/finance/overview", verifyAdminAuth, adminFinance.getFinancialOverview);
router.get("/finance/settlements", verifyAdminAuth, adminFinance.getDriverSettlements);

// 9. Customer Management
router.get("/customers", verifyAdminAuth, adminCustomer.getCustomers);
router.get("/customers/:customerId", verifyAdminAuth, adminCustomer.getCustomerDetails);

// 10. Audit Logs & Staff Management
router.get("/audit-logs", verifyAdminAuth, adminAudit.getAuditLogs);
router.get("/staff", verifyAdminAuth, requireRoles("super_admin"), adminAudit.getAdminUsers);
router.post("/staff", verifyAdminAuth, requireRoles("super_admin"), adminAudit.createAdminUser);

module.exports = router;

