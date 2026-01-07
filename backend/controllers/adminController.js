// controllers/adminController.js
const User = require("../models/User");
const Location = require("../models/Location");
const Attendance = require("../models/Attendance");

// @desc    Get all employees
// @route   GET /api/admin/employees
// @access  Private (Admin)
exports.getAllEmployees = async (req, res) => {
  try {
    const employees = await User.find({ role: "EMPLOYEE" })
      .select("-password")
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: employees.length,
      data: {
        employees,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error fetching employees",
      error: error.message,
    });
  }
};

// @desc    Get checked-in employees with details
// @route   GET /api/admin/checked-in-employees
// @access  Private (Admin)
exports.getCheckedInEmployees = async (req, res) => {
  try {
    const today = new Date().toISOString().split("T")[0];

    // Find all checked-in employees for today
    const checkedInAttendance = await Attendance.find({
      date: today,
      status: "CHECKED_IN",
    }).populate("employeeId", "name email phone department employeeId");

    // Get latest location for each checked-in employee
    const employeesWithLocation = await Promise.all(
      checkedInAttendance.map(async (attendance) => {
        const latestLocation = await Location.findOne({
          employeeId: attendance.employeeId._id,
        })
          .sort({ timestamp: -1 })
          .limit(1);

        return {
          employee: attendance.employeeId,
          attendance: {
            checkInTime: attendance.checkInTime,
            checkInAddress: attendance.checkInAddress,
            distanceFromOffice: attendance.distanceFromOffice,
            estimatedTimeToOffice: attendance.estimatedTimeToOffice,
          },
          location: latestLocation
            ? {
                latitude: latestLocation.location.coordinates[1],
                longitude: latestLocation.location.coordinates[0],
                address: latestLocation.address,
                timestamp: latestLocation.timestamp,
                isInOffice: latestLocation.isInOffice,
                accuracy: latestLocation.accuracy,
              }
            : null,
        };
      })
    );

    res.status(200).json({
      success: true,
      count: employeesWithLocation.length,
      data: {
        employees: employeesWithLocation,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error fetching checked-in employees",
      error: error.message,
    });
  }
};

// @desc    Get not checked-in employees
// @route   GET /api/admin/not-checked-in-employees
// @access  Private (Admin)
exports.getNotCheckedInEmployees = async (req, res) => {
  try {
    const today = new Date().toISOString().split("T")[0];

    // Get all employees
    const allEmployees = await User.find({ role: "EMPLOYEE" }).select(
      "-password"
    );

    // Get checked-in employee IDs
    const checkedInAttendance = await Attendance.find({
      date: today,
      status: { $in: ["CHECKED_IN", "CHECKED_OUT"] },
    }).select("employeeId");

    const checkedInIds = checkedInAttendance.map((att) =>
      att.employeeId.toString()
    );

    // Filter not checked-in employees
    const notCheckedInEmployees = allEmployees.filter(
      (emp) => !checkedInIds.includes(emp._id.toString())
    );

    res.status(200).json({
      success: true,
      count: notCheckedInEmployees.length,
      data: {
        employees: notCheckedInEmployees,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error fetching not checked-in employees",
      error: error.message,
    });
  }
};

// @desc    Get all employees with their current status
// @route   GET /api/admin/employees-status
// @access  Private (Admin)
exports.getEmployeesStatus = async (req, res) => {
  try {
    const today = new Date().toISOString().split("T")[0];

    const allEmployees = await User.find({ role: "EMPLOYEE" }).select(
      "-password"
    );

    const employeesWithStatus = await Promise.all(
      allEmployees.map(async (employee) => {
        // Get today's attendance
        const attendance = await Attendance.findOne({
          employeeId: employee._id,
          date: today,
        });

        // Get latest location
        const latestLocation = await Location.findOne({
          employeeId: employee._id,
        })
          .sort({ timestamp: -1 })
          .limit(1);

        return {
          employee,
          status: attendance ? attendance.status : "NOT_CHECKED_IN",
          attendance: attendance
            ? {
                checkInTime: attendance.checkInTime,
                checkOutTime: attendance.checkOutTime,
                totalHours: attendance.totalHours,
                checkInAddress: attendance.checkInAddress,
              }
            : null,
          location: latestLocation
            ? {
                latitude: latestLocation.location.coordinates[1],
                longitude: latestLocation.location.coordinates[0],
                address: latestLocation.address,
                timestamp: latestLocation.timestamp,
                isInOffice: latestLocation.isInOffice,
              }
            : null,
        };
      })
    );

    res.status(200).json({
      success: true,
      count: employeesWithStatus.length,
      data: {
        employees: employeesWithStatus,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error fetching employees status",
      error: error.message,
    });
  }
};

// @desc    Get employee location history
// @route   GET /api/admin/employee/:employeeId/locations
// @access  Private (Admin)
exports.getEmployeeLocationHistory = async (req, res) => {
  try {
    const { employeeId } = req.params;
    const { startDate, endDate, limit = 100 } = req.query;

    let query = { employeeId };

    if (startDate && endDate) {
      query.timestamp = {
        $gte: new Date(startDate),
        $lte: new Date(endDate),
      };
    }

    const locations = await Location.find(query)
      .sort({ timestamp: -1 })
      .limit(parseInt(limit));

    res.status(200).json({
      success: true,
      count: locations.length,
      data: {
        locations,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error fetching location history",
      error: error.message,
    });
  }
};

// @desc    Get employee attendance history
// @route   GET /api/admin/employee/:employeeId/attendance
// @access  Private (Admin)
exports.getEmployeeAttendanceHistory = async (req, res) => {
  try {
    const { employeeId } = req.params;
    const { startDate, endDate, limit = 30 } = req.query;

    let query = { employeeId };

    if (startDate && endDate) {
      query.date = {
        $gte: startDate,
        $lte: endDate,
      };
    }

    const attendance = await Attendance.find(query)
      .sort({ date: -1 })
      .limit(parseInt(limit))
      .populate("employeeId", "name email employeeId department");

    res.status(200).json({
      success: true,
      count: attendance.length,
      data: {
        attendance,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error fetching attendance history",
      error: error.message,
    });
  }
};

// @desc    Get dashboard statistics
// @route   GET /api/admin/dashboard-stats
// @access  Private (Admin)
exports.getDashboardStats = async (req, res) => {
  try {
    const today = new Date().toISOString().split("T")[0];

    // Total employees
    const totalEmployees = await User.countDocuments({ role: "EMPLOYEE" });

    // Checked-in today
    const checkedInToday = await Attendance.countDocuments({
      date: today,
      status: "CHECKED_IN",
    });

    // Checked-out today
    const checkedOutToday = await Attendance.countDocuments({
      date: today,
      status: "CHECKED_OUT",
    });

    // Not checked-in today
    const notCheckedIn = totalEmployees - (checkedInToday + checkedOutToday);

    // Employees in office (geofence)
    const inOfficeCount = await Location.countDocuments({
      isInOffice: true,
      timestamp: {
        $gte: new Date(Date.now() - 5 * 60 * 1000), // Last 5 minutes
      },
    });

    res.status(200).json({
      success: true,
      data: {
        totalEmployees,
        checkedInToday,
        checkedOutToday,
        notCheckedIn,
        inOfficeCount,
        date: today,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error fetching dashboard stats",
      error: error.message,
    });
  }
};

// @desc    Create employee (Admin only)
// @route   POST /api/admin/employees
// @access  Private (Admin)
exports.createEmployee = async (req, res) => {
  try {
    const { name, email, password, phone, department, employeeId } = req.body;

    // Check if user exists
    const userExists = await User.findOne({ email });
    if (userExists) {
      return res.status(400).json({
        success: false,
        message: "User with this email already exists",
      });
    }

    // Check if employee ID exists
    if (employeeId) {
      const empIdExists = await User.findOne({ employeeId });
      if (empIdExists) {
        return res.status(400).json({
          success: false,
          message: "Employee ID already exists",
        });
      }
    }

    // Create employee
    const employee = await User.create({
      name,
      email,
      password,
      phone,
      department,
      employeeId,
      role: "EMPLOYEE",
    });

    res.status(201).json({
      success: true,
      message: "Employee created successfully",
      data: {
        employee: employee.toSafeObject(),
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error creating employee",
      error: error.message,
    });
  }
};

// @desc    Update employee
// @route   PUT /api/admin/employees/:id
// @access  Private (Admin)
exports.updateEmployee = async (req, res) => {
  try {
    const { name, phone, department, isActive } = req.body;

    const employee = await User.findByIdAndUpdate(
      req.params.id,
      { name, phone, department, isActive },
      { new: true, runValidators: true }
    ).select("-password");

    if (!employee) {
      return res.status(404).json({
        success: false,
        message: "Employee not found",
      });
    }

    res.status(200).json({
      success: true,
      message: "Employee updated successfully",
      data: {
        employee,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error updating employee",
      error: error.message,
    });
  }
};

// @desc    Delete employee
// @route   DELETE /api/admin/employees/:id
// @access  Private (Admin)
exports.deleteEmployee = async (req, res) => {
  try {
    const employee = await User.findById(req.params.id);

    if (!employee) {
      return res.status(404).json({
        success: false,
        message: "Employee not found",
      });
    }

    if (employee.role === "ADMIN") {
      return res.status(400).json({
        success: false,
        message: "Cannot delete admin user",
      });
    }

    await employee.deleteOne();

    res.status(200).json({
      success: true,
      message: "Employee deleted successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error deleting employee",
      error: error.message,
    });
  }
};

// Add this new function to adminController.js

// @desc    Get reached employees (in office)
// @route   GET /api/admin/reached-employees
// @access  Private (Admin)
// @desc    Get reached employees (in office)
// @route   GET /api/admin/reached-employees
// @access  Private (Admin)
exports.getReachedEmployees = async (req, res) => {
  try {
    const today = new Date().toISOString().split("T")[0];

    const reachedAttendance = await Attendance.find({
      date: today,
      status: "REACHED_OFFICE",
    }).populate("employeeId", "name email phone department employeeId");

    const employeesWithDetails = await Promise.all(
      reachedAttendance.map(async (attendance) => {
        const latestLocation = await Location.findOne({
          employeeId: attendance.employeeId._id,
        })
          .sort({ timestamp: -1 })
          .limit(1);

        return {
          employee: attendance.employeeId,
          attendance: {
            checkInTime: attendance.checkInTime,
            checkInAddress: attendance.checkInAddress,
          },
          location: latestLocation
            ? {
                latitude: latestLocation.location.coordinates[1],
                longitude: latestLocation.location.coordinates[0],
                address: latestLocation.address,
                timestamp: latestLocation.timestamp,
              }
            : null,
        };
      })
    );

    res.status(200).json({
      success: true,
      count: employeesWithDetails.length,
      data: {
        employees: employeesWithDetails,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error fetching reached employees",
      error: error.message,
    });
  }
};
