// routes/employee.js
const express = require("express");
const router = express.Router();
const {
  checkIn,
  checkOut,
  updateLocation,
  getMyAttendance,
  getMyStatus,
} = require("../controllers/employeeController");
const { protect, authorize } = require("../middleware/auth");

// All routes are protected and employee-only
router.use(protect);
router.use(authorize("EMPLOYEE"));

router.post("/check-in", checkIn);
router.post("/check-out", checkOut);
router.post("/location", updateLocation);
router.get("/attendance", getMyAttendance);
router.get("/status", getMyStatus);

module.exports = router;
