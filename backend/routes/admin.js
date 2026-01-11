// routes/admin.js
const express = require("express");
const router = express.Router();
const { protect, authorize } = require("../middleware/auth");
const User = require("../models/User");
const Attendance = require("../models/Attendance");

// All routes are protected and admin-only
router.use(protect);
router.use(authorize("ADMIN"));

// GET /api/admin/checked-in-employees
router.get("/checked-in-employees", async (req, res) => {
  try {
    console.log("📋 Getting checked-in employees with locations...");

    const today = new Date().toISOString().split("T")[0];

    // ✅ FIX: Use employeeId (not employee) and populate it
    const attendances = await Attendance.find({
      date: today,
      status: "CHECKED_IN",
    }).populate("employeeId", "-password"); // ← Changed from "employee" to "employeeId"

    const employeesWithLocation = attendances.map((attendance) => {
      const employee = attendance.employeeId; // ← This is now correct

      if (!employee) {
        console.log(`⚠️ No employee found for attendance ${attendance._id}`);
        return null;
      }

      // Get current location (prefer currentLocation over checkInLocation)
      const location = attendance.currentLocation || attendance.checkInLocation;
      const lat = location?.coordinates?.[1] || null;
      const lng = location?.coordinates?.[0] || null;

      console.log(`📍 ${employee.name}: ${lat}, ${lng}`);

      return {
        employee: {
          _id: employee._id,
          name: employee.name,
          email: employee.email,
          employeeId: employee.employeeId,
          phone: employee.phone,
          department: employee.department,
        },
        attendance: {
          _id: attendance._id,
          checkInTime: attendance.checkInTime,
          checkInLocation: attendance.checkInLocation,
          currentLocation: attendance.currentLocation,
          hasReachedOffice: attendance.status === "REACHED_OFFICE",
          isCheckedIn: attendance.status === "CHECKED_IN",
        },
        latitude: lat,
        longitude: lng,
        lastUpdate: location?.timestamp || attendance.checkInTime,
        address: location?.address || "Unknown",
      };
    });

    // Filter out null values
    const validEmployees = employeesWithLocation.filter((emp) => emp !== null);

    console.log(`✅ Returning ${validEmployees.length} checked-in employees`);

    res.json({
      success: true,
      count: validEmployees.length,
      data: {
        employees: validEmployees,
      },
    });
  } catch (error) {
    console.error("❌ Error getting checked-in employees:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// GET /api/admin/employees
router.get("/employees", async (req, res) => {
  try {
    console.log("📋 Getting all employees...");

    const employees = await User.find({ role: "EMPLOYEE" }).select("-password");

    console.log(`✅ Found ${employees.length} employees`);

    res.json({
      success: true,
      count: employees.length,
      data: {
        employees,
      },
    });
  } catch (error) {
    console.error("❌ Error getting employees:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

// GET /api/admin/reached-employees
router.get("/reached-employees", async (req, res) => {
  try {
    console.log("📋 Getting reached employees...");

    const today = new Date().toISOString().split("T")[0];

    // ✅ FIX: Use employeeId
    const attendances = await Attendance.find({
      date: today,
      status: "REACHED_OFFICE",
    }).populate("employeeId", "-password");

    const employees = attendances.map((att) => ({
      employee: att.employeeId,
      attendance: att,
    }));

    console.log(`✅ Found ${employees.length} reached employees`);

    res.json({
      success: true,
      count: employees.length,
      data: {
        employees,
      },
    });
  } catch (error) {
    console.error("❌ Error getting reached employees:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

// GET /api/admin/not-checked-in-employees
router.get("/not-checked-in-employees", async (req, res) => {
  try {
    console.log("📋 Getting not checked-in employees...");

    const today = new Date().toISOString().split("T")[0];

    const allEmployees = await User.find({ role: "EMPLOYEE" }).select(
      "-password"
    );

    // ✅ FIX: Use employeeId
    const checkedInIds = await Attendance.find({
      date: today,
    }).distinct("employeeId");

    const notCheckedIn = allEmployees.filter(
      (emp) => !checkedInIds.some((id) => id.toString() === emp._id.toString())
    );

    console.log(`✅ Found ${notCheckedIn.length} not checked-in employees`);

    res.json({
      success: true,
      count: notCheckedIn.length,
      data: {
        employees: notCheckedIn,
      },
    });
  } catch (error) {
    console.error("❌ Error getting not checked-in employees:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});
// GET /api/admin/checked-out-employees (ADD THIS)
router.get("/checked-out-employees", async (req, res) => {
  try {
    console.log("📋 Getting checked-out employees...");

    const today = new Date().toISOString().split("T")[0];

    const attendances = await Attendance.find({
      date: today,
      status: "CHECKED_OUT",
    }).populate("employeeId", "-password");

    const employees = attendances
      .filter((att) => att.employeeId) // Filter out null
      .map((att) => ({
        employee: {
          _id: att.employeeId._id,
          name: att.employeeId.name,
          email: att.employeeId.email,
          employeeId: att.employeeId.employeeId,
          phone: att.employeeId.phone,
          department: att.employeeId.department,
        },
        attendance: {
          checkInTime: att.checkInTime,
          checkOutTime: att.checkOutTime,
          totalHours: att.totalHours || 0,
          checkInAddress: att.checkInAddress || "N/A",
          checkOutAddress: att.checkOutAddress || "N/A",
        },
      }));

    console.log(`✅ Found ${employees.length} checked-out employees`);

    res.json({
      success: true,
      count: employees.length,
      data: {
        employees,
      },
    });
  } catch (error) {
    console.error("❌ Error getting checked-out employees:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// GET /api/admin/dashboard-stats
router.get("/dashboard-stats", async (req, res) => {
  try {
    console.log("📊 Getting dashboard stats...");

    const today = new Date().toISOString().split("T")[0];

    const totalEmployees = await User.countDocuments({ role: "EMPLOYEE" });

    const todayAttendances = await Attendance.find({ date: today });

    const checkedInCount = todayAttendances.filter(
      (att) => att.status === "CHECKED_IN"
    ).length;

    const reachedCount = todayAttendances.filter(
      (att) => att.status === "REACHED_OFFICE"
    ).length;

    const checkedOutCount = todayAttendances.filter(
      (att) => att.status === "CHECKED_OUT"
    ).length;

    const notCheckedInCount = totalEmployees - todayAttendances.length;

    const stats = {
      totalEmployees,
      checkedInToday: checkedInCount, // 🔥 rename
      inOfficeCount: reachedCount, // 🔥 rename
      checkedOutToday: checkedOutCount, // 🔥 rename (optional now)
      notCheckedIn: notCheckedInCount,
    };

    console.log("✅ Dashboard stats:", stats);

    res.json({
      success: true,
      data: stats,
    });
  } catch (error) {
    console.error("❌ Error getting dashboard stats:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
    });
  }
});

module.exports = router;
