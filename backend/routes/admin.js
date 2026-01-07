// routes/admin.js
const express = require("express");
const router = express.Router();
const {
  getAllEmployees,
  getCheckedInEmployees,
  getNotCheckedInEmployees,
  getReachedEmployees, // ✅ ADD THIS
  getEmployeesStatus,
  getEmployeeLocationHistory,
  getEmployeeAttendanceHistory,
  getDashboardStats,
  createEmployee,
  updateEmployee,
  deleteEmployee,
} = require("../controllers/adminController");
const { protect, authorize } = require("../middleware/auth");

// All routes are protected and admin-only
router.use(protect);
router.use(authorize("ADMIN"));

// Dashboard & Stats
router.get("/dashboard-stats", getDashboardStats);

// Employee Management
router.get("/employees", getAllEmployees);
router.post("/employees", createEmployee);
router.put("/employees/:id", updateEmployee);
router.delete("/employees/:id", deleteEmployee);

// Employee Status & Tracking
router.get("/employees-status", getEmployeesStatus);
router.get("/checked-in-employees", getCheckedInEmployees);
router.get("/not-checked-in-employees", getNotCheckedInEmployees);
router.get("/reached-employees", getReachedEmployees); // ✅ ADD THIS

// Employee History
router.get("/employee/:employeeId/locations", getEmployeeLocationHistory);
router.get("/employee/:employeeId/attendance", getEmployeeAttendanceHistory);

module.exports = router;
