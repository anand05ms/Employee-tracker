// // controllers/adminController.js
// const User = require("../models/User");
// const Location = require("../models/Location");
// const Attendance = require("../models/Attendance");

// // @desc    Get all employees
// // @route   GET /api/admin/employees
// // @access  Private (Admin)
// exports.getAllEmployees = async (req, res) => {
//   try {
//     const employees = await User.find({ role: "EMPLOYEE" })
//       .select("-password")
//       .sort({ createdAt: -1 });

//     res.status(200).json({
//       success: true,
//       count: employees.length,
//       data: {
//         employees,
//       },
//     });
//   } catch (error) {
//     res.status(500).json({
//       success: false,
//       message: "Error fetching employees",
//       error: error.message,
//     });
//   }
// };

// // @desc    Get checked-in employees with details (FIXED - only CHECKED_IN, not REACHED)
// // @route   GET /api/admin/checked-in-employees
// // @access  Private (Admin)
// exports.getCheckedInEmployees = async (req, res) => {
//   try {
//     const today = new Date().toISOString().split("T")[0];

//     // ✅ ONLY get CHECKED_IN employees (on the way to office)
//     const checkedInAttendance = await Attendance.find({
//       date: today,
//       status: "CHECKED_IN",
//     }).populate("employeeId", "name email phone department employeeId");

//     // ✅ Handle null/missing employee data
//     const validAttendance = checkedInAttendance.filter(
//       (att) => att.employeeId && att.employeeId._id
//     );

//     // Get latest location for each checked-in employee
//     const employeesWithLocation = await Promise.all(
//       validAttendance.map(async (attendance) => {
//         const latestLocation = await Location.findOne({
//           employeeId: attendance.employeeId._id,
//         })
//           .sort({ timestamp: -1 })
//           .limit(1);

//         return {
//           employee: {
//             id: attendance.employeeId._id,
//             name: attendance.employeeId.name,
//             email: attendance.employeeId.email,
//             phone: attendance.employeeId.phone,
//             department: attendance.employeeId.department,
//             employeeId: attendance.employeeId.employeeId,
//           },
//           attendance: {
//             checkInTime: attendance.checkInTime,
//             checkInAddress: attendance.checkInAddress,
//             distanceFromOffice: attendance.distanceFromOffice || 0,
//             estimatedTimeToOffice: attendance.estimatedTimeToOffice || 0,
//           },
//           location: latestLocation
//             ? {
//                 latitude: latestLocation.location.coordinates[1],
//                 longitude: latestLocation.location.coordinates[0],
//                 address: latestLocation.address || "Unknown",
//                 timestamp: latestLocation.timestamp,
//                 isInOffice: latestLocation.isInOffice || false,
//                 accuracy: latestLocation.accuracy || 0,
//               }
//             : null,
//         };
//       })
//     );

//     res.status(200).json({
//       success: true,
//       count: employeesWithLocation.length,
//       data: {
//         employees: employeesWithLocation,
//       },
//     });
//   } catch (error) {
//     console.error("Error in getCheckedInEmployees:", error);
//     res.status(500).json({
//       success: false,
//       message: "Error fetching checked-in employees",
//       error: error.message,
//     });
//   }
// };

// // @desc    Get reached employees (in office) - FIXED
// // @route   GET /api/admin/reached-employees
// // @access  Private (Admin)
// exports.getReachedEmployees = async (req, res) => {
//   try {
//     const today = new Date().toISOString().split("T")[0];

//     // ✅ Get employees who reached office (status = REACHED_OFFICE)
//     const reachedAttendance = await Attendance.find({
//       date: today,
//       status: "REACHED_OFFICE",
//     }).populate("employeeId", "name email phone department employeeId");

//     // ✅ Filter out null employees
//     const validAttendance = reachedAttendance.filter(
//       (att) => att.employeeId && att.employeeId._id
//     );

//     const employeesWithDetails = await Promise.all(
//       validAttendance.map(async (attendance) => {
//         const latestLocation = await Location.findOne({
//           employeeId: attendance.employeeId._id,
//         })
//           .sort({ timestamp: -1 })
//           .limit(1);

//         return {
//           employee: {
//             id: attendance.employeeId._id,
//             name: attendance.employeeId.name,
//             email: attendance.employeeId.email,
//             phone: attendance.employeeId.phone,
//             department: attendance.employeeId.department,
//             employeeId: attendance.employeeId.employeeId,
//           },
//           attendance: {
//             checkInTime: attendance.checkInTime,
//             checkInAddress: attendance.checkInAddress || "Office Location",
//             reachedOfficeTime:
//               attendance.reachedOfficeTime || attendance.checkInTime,
//           },
//           location: latestLocation
//             ? {
//                 latitude: latestLocation.location.coordinates[1],
//                 longitude: latestLocation.location.coordinates[0],
//                 address: latestLocation.address || "Office",
//                 timestamp: latestLocation.timestamp,
//                 isInOffice: true,
//               }
//             : null,
//         };
//       })
//     );

//     res.status(200).json({
//       success: true,
//       count: employeesWithDetails.length,
//       data: {
//         employees: employeesWithDetails,
//       },
//     });
//   } catch (error) {
//     console.error("Error in getReachedEmployees:", error);
//     res.status(500).json({
//       success: false,
//       message: "Error fetching reached employees",
//       error: error.message,
//     });
//   }
// };

// // @desc    Get checked-out employees - FIXED
// // @route   GET /api/admin/checked-out-employees
// // @access  Private (Admin)
// exports.getCheckedOutEmployees = async (req, res) => {
//   try {
//     const today = new Date().toISOString().split("T")[0];

//     // ✅ Get CHECKED_OUT employees
//     const checkedOutAttendance = await Attendance.find({
//       date: today,
//       status: "CHECKED_OUT",
//     }).populate("employeeId", "name email phone department employeeId");

//     // ✅ Filter out null employees
//     const validAttendance = checkedOutAttendance.filter(
//       (att) => att.employeeId && att.employeeId._id
//     );

//     const employeesWithDetails = validAttendance.map((attendance) => ({
//       employee: {
//         id: attendance.employeeId._id,
//         name: attendance.employeeId.name,
//         email: attendance.employeeId.email,
//         phone: attendance.employeeId.phone,
//         department: attendance.employeeId.department,
//         employeeId: attendance.employeeId.employeeId,
//       },
//       attendance: {
//         checkInTime: attendance.checkInTime,
//         checkOutTime: attendance.checkOutTime,
//         totalHours: attendance.totalHours || 0,
//         checkInAddress: attendance.checkInAddress || "N/A",
//         checkOutAddress: attendance.checkOutAddress || "N/A",
//       },
//     }));

//     res.status(200).json({
//       success: true,
//       count: employeesWithDetails.length,
//       data: {
//         employees: employeesWithDetails,
//       },
//     });
//   } catch (error) {
//     console.error("Error in getCheckedOutEmployees:", error);
//     res.status(500).json({
//       success: false,
//       message: "Error fetching checked-out employees",
//       error: error.message,
//     });
//   }
// };

// // @desc    Get not checked-in employees
// // @route   GET /api/admin/not-checked-in-employees
// // @access  Private (Admin)
// exports.getNotCheckedInEmployees = async (req, res) => {
//   try {
//     const today = new Date().toISOString().split("T")[0];

//     // Get all employees
//     const allEmployees = await User.find({ role: "EMPLOYEE" }).select(
//       "-password"
//     );

//     // Get employees with attendance today (any status)
//     const attendanceToday = await Attendance.find({
//       date: today,
//     }).select("employeeId");

//     const attendanceIds = attendanceToday.map((att) =>
//       att.employeeId.toString()
//     );

//     // Filter not checked-in employees
//     const notCheckedInEmployees = allEmployees.filter(
//       (emp) => !attendanceIds.includes(emp._id.toString())
//     );

//     res.status(200).json({
//       success: true,
//       count: notCheckedInEmployees.length,
//       data: {
//         employees: notCheckedInEmployees,
//       },
//     });
//   } catch (error) {
//     console.error("Error in getNotCheckedInEmployees:", error);
//     res.status(500).json({
//       success: false,
//       message: "Error fetching not checked-in employees",
//       error: error.message,
//     });
//   }
// };

// // @desc    Get all employees with their current status
// // @route   GET /api/admin/employees-status
// // @access  Private (Admin)
// exports.getEmployeesStatus = async (req, res) => {
//   try {
//     const today = new Date().toISOString().split("T")[0];

//     const allEmployees = await User.find({ role: "EMPLOYEE" }).select(
//       "-password"
//     );

//     const employeesWithStatus = await Promise.all(
//       allEmployees.map(async (employee) => {
//         // Get today's attendance
//         const attendance = await Attendance.findOne({
//           employeeId: employee._id,
//           date: today,
//         });

//         // Get latest location (last 30 minutes only)
//         const latestLocation = await Location.findOne({
//           employeeId: employee._id,
//           timestamp: {
//             $gte: new Date(Date.now() - 30 * 60 * 1000), // Last 30 minutes
//           },
//         })
//           .sort({ timestamp: -1 })
//           .limit(1);

//         return {
//           employee: {
//             id: employee._id,
//             name: employee.name,
//             email: employee.email,
//             phone: employee.phone,
//             department: employee.department,
//             employeeId: employee.employeeId,
//             isActive: employee.isActive,
//           },
//           status: attendance ? attendance.status : "NOT_CHECKED_IN",
//           attendance: attendance
//             ? {
//                 checkInTime: attendance.checkInTime,
//                 checkOutTime: attendance.checkOutTime,
//                 totalHours: attendance.totalHours || 0,
//                 checkInAddress: attendance.checkInAddress || "N/A",
//                 checkOutAddress: attendance.checkOutAddress || "N/A",
//               }
//             : null,
//           location: latestLocation
//             ? {
//                 latitude: latestLocation.location.coordinates[1],
//                 longitude: latestLocation.location.coordinates[0],
//                 address: latestLocation.address || "Unknown",
//                 timestamp: latestLocation.timestamp,
//                 isInOffice: latestLocation.isInOffice || false,
//               }
//             : null,
//         };
//       })
//     );

//     res.status(200).json({
//       success: true,
//       count: employeesWithStatus.length,
//       data: {
//         employees: employeesWithStatus,
//       },
//     });
//   } catch (error) {
//     console.error("Error in getEmployeesStatus:", error);
//     res.status(500).json({
//       success: false,
//       message: "Error fetching employees status",
//       error: error.message,
//     });
//   }
// };

// // @desc    Get dashboard statistics - FIXED (type-safe)
// // @route   GET /api/admin/dashboard-stats
// // @access  Private (Admin)
// exports.getDashboardStats = async (req, res) => {
//   try {
//     const today = new Date().toISOString().split("T")[0];

//     // Total employees
//     const totalEmployees = await User.countDocuments({ role: "EMPLOYEE" });

//     // ✅ Checked-in today (on the way)
//     const checkedInToday = await Attendance.countDocuments({
//       date: today,
//       status: "CHECKED_IN",
//     });

//     // ✅ Reached office (in office)
//     const inOfficeCount = await Attendance.countDocuments({
//       date: today,
//       status: "REACHED_OFFICE",
//     });

//     // ✅ Checked-out today
//     const checkedOutToday = await Attendance.countDocuments({
//       date: today,
//       status: "CHECKED_OUT",
//     });

//     // ✅ Not checked-in today
//     const notCheckedIn =
//       totalEmployees - (checkedInToday + inOfficeCount + checkedOutToday);

//     res.status(200).json({
//       success: true,
//       data: {
//         totalEmployees: totalEmployees || 0,
//         checkedInToday: checkedInToday || 0,
//         inOfficeCount: inOfficeCount || 0,
//         checkedOutToday: checkedOutToday || 0,
//         notCheckedIn: notCheckedIn >= 0 ? notCheckedIn : 0,
//         date: today,
//       },
//     });
//   } catch (error) {
//     console.error("Error in getDashboardStats:", error);
//     res.status(500).json({
//       success: false,
//       message: "Error fetching dashboard stats",
//       error: error.message,
//     });
//   }
// };

// // @desc    Get employee location history
// // @route   GET /api/admin/employee/:employeeId/locations
// // @access  Private (Admin)
// exports.getEmployeeLocationHistory = async (req, res) => {
//   try {
//     const { employeeId } = req.params;
//     const { startDate, endDate, limit = 100 } = req.query;

//     let query = { employeeId };

//     if (startDate && endDate) {
//       query.timestamp = {
//         $gte: new Date(startDate),
//         $lte: new Date(endDate),
//       };
//     }

//     const locations = await Location.find(query)
//       .sort({ timestamp: -1 })
//       .limit(parseInt(limit));

//     res.status(200).json({
//       success: true,
//       count: locations.length,
//       data: {
//         locations,
//       },
//     });
//   } catch (error) {
//     res.status(500).json({
//       success: false,
//       message: "Error fetching location history",
//       error: error.message,
//     });
//   }
// };

// // @desc    Get employee attendance history
// // @route   GET /api/admin/employee/:employeeId/attendance
// // @access  Private (Admin)
// exports.getEmployeeAttendanceHistory = async (req, res) => {
//   try {
//     const { employeeId } = req.params;
//     const { startDate, endDate, limit = 30 } = req.query;

//     let query = { employeeId };

//     if (startDate && endDate) {
//       query.date = {
//         $gte: startDate,
//         $lte: endDate,
//       };
//     }

//     const attendance = await Attendance.find(query)
//       .sort({ date: -1 })
//       .limit(parseInt(limit))
//       .populate("employeeId", "name email employeeId department");

//     res.status(200).json({
//       success: true,
//       count: attendance.length,
//       data: {
//         attendance,
//       },
//     });
//   } catch (error) {
//     res.status(500).json({
//       success: false,
//       message: "Error fetching attendance history",
//       error: error.message,
//     });
//   }
// };

// // @desc    Create employee (Admin only)
// // @route   POST /api/admin/employees
// // @access  Private (Admin)
// exports.createEmployee = async (req, res) => {
//   try {
//     const { name, email, password, phone, department, employeeId } = req.body;

//     // Check if user exists
//     const userExists = await User.findOne({ email });
//     if (userExists) {
//       return res.status(400).json({
//         success: false,
//         message: "User with this email already exists",
//       });
//     }

//     // Check if employee ID exists
//     if (employeeId) {
//       const empIdExists = await User.findOne({ employeeId });
//       if (empIdExists) {
//         return res.status(400).json({
//           success: false,
//           message: "Employee ID already exists",
//         });
//       }
//     }

//     // Create employee
//     const employee = await User.create({
//       name,
//       email,
//       password,
//       phone,
//       department,
//       employeeId,
//       role: "EMPLOYEE",
//     });

//     res.status(201).json({
//       success: true,
//       message: "Employee created successfully",
//       data: {
//         employee: employee.toSafeObject(),
//       },
//     });
//   } catch (error) {
//     res.status(500).json({
//       success: false,
//       message: "Error creating employee",
//       error: error.message,
//     });
//   }
// };

// // @desc    Update employee
// // @route   PUT /api/admin/employees/:id
// // @access  Private (Admin)
// exports.updateEmployee = async (req, res) => {
//   try {
//     const { name, phone, department, isActive } = req.body;

//     const employee = await User.findByIdAndUpdate(
//       req.params.id,
//       { name, phone, department, isActive },
//       { new: true, runValidators: true }
//     ).select("-password");

//     if (!employee) {
//       return res.status(404).json({
//         success: false,
//         message: "Employee not found",
//       });
//     }

//     res.status(200).json({
//       success: true,
//       message: "Employee updated successfully",
//       data: {
//         employee,
//       },
//     });
//   } catch (error) {
//     res.status(500).json({
//       success: false,
//       message: "Error updating employee",
//       error: error.message,
//     });
//   }
// };

// // @desc    Delete employee
// // @route   DELETE /api/admin/employees/:id
// // @access  Private (Admin)
// exports.deleteEmployee = async (req, res) => {
//   try {
//     const employee = await User.findById(req.params.id);

//     if (!employee) {
//       return res.status(404).json({
//         success: false,
//         message: "Employee not found",
//       });
//     }

//     if (employee.role === "ADMIN") {
//       return res.status(400).json({
//         success: false,
//         message: "Cannot delete admin user",
//       });
//     }

//     await employee.deleteOne();

//     res.status(200).json({
//       success: true,
//       message: "Employee deleted successfully",
//     });
//   } catch (error) {
//     res.status(500).json({
//       success: false,
//       message: "Error deleting employee",
//       error: error.message,
//     });
//   }
// };
const User = require("../models/User");
const Location = require("../models/Location");
const Attendance = require("../models/Attendance");

/* ======================================================
   HELPERS
====================================================== */
const getToday = () => new Date().toISOString().split("T")[0];

const getLatestAttendancePerEmployee = async () => {
  const today = getToday();

  return Attendance.aggregate([
    { $match: { date: today } },
    { $sort: { checkInTime: -1 } }, // latest first
    {
      $group: {
        _id: "$employeeId",
        attendance: { $first: "$$ROOT" },
      },
    },
  ]);
};

/* ======================================================
   ALL EMPLOYEES
====================================================== */
exports.getAllEmployees = async (req, res) => {
  try {
    const employees = await User.find({ role: "EMPLOYEE" })
      .select("-password")
      .sort({ createdAt: -1 });

    res.json({ success: true, data: { employees } });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
};

/* ======================================================
   CHECKED IN (ON THE WAY)
====================================================== */
exports.getCheckedInEmployees = async (req, res) => {
  try {
    const latest = await getLatestAttendancePerEmployee();

    const result = await Promise.all(
      latest
        .filter((r) => r.attendance.status === "CHECKED_IN")
        .map(async (r) => {
          const emp = await User.findById(r._id).select(
            "name email phone department employeeId"
          );
          const loc = await Location.findOne({ employeeId: r._id })
            .sort({ timestamp: -1 })
            .limit(1);

          return {
            employee: emp,
            attendance: r.attendance,
            location: loc,
          };
        })
    );

    res.json({ success: true, data: { employees: result } });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
};

/* ======================================================
   IN OFFICE
====================================================== */
exports.getReachedEmployees = async (req, res) => {
  try {
    const latest = await getLatestAttendancePerEmployee();

    const result = await Promise.all(
      latest
        .filter((r) => r.attendance.status === "REACHED_OFFICE")
        .map(async (r) => {
          const emp = await User.findById(r._id).select(
            "name email phone department employeeId"
          );
          const loc = await Location.findOne({ employeeId: r._id })
            .sort({ timestamp: -1 })
            .limit(1);

          return {
            employee: emp,
            attendance: r.attendance,
            location: loc,
          };
        })
    );

    res.json({ success: true, data: { employees: result } });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
};

/* ======================================================
   CHECKED OUT
====================================================== */
exports.getCheckedOutEmployees = async (req, res) => {
  try {
    const latest = await getLatestAttendancePerEmployee();

    const result = await Promise.all(
      latest
        .filter((r) => r.attendance.status === "CHECKED_OUT")
        .map(async (r) => {
          const emp = await User.findById(r._id).select(
            "name email phone department employeeId"
          );

          return {
            employee: emp,
            attendance: {
              checkInTime: r.attendance.checkInTime,
              checkOutTime: r.attendance.checkOutTime,
              totalHours: r.attendance.totalHours || 0,
              checkInAddress: r.attendance.checkInAddress || "N/A",
              checkOutAddress: r.attendance.checkOutAddress || "N/A",
            },
          };
        })
    );

    res.json({ success: true, data: { employees: result } });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
};

/* ======================================================
   NOT CHECKED IN TODAY
====================================================== */
exports.getNotCheckedInEmployees = async (req, res) => {
  try {
    const latest = await getLatestAttendancePerEmployee();
    const activeIds = latest.map((r) => r._id.toString());

    const employees = await User.find({
      role: "EMPLOYEE",
      _id: { $nin: activeIds },
    }).select("-password");

    res.json({ success: true, data: { employees } });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
};

/* ======================================================
   DASHBOARD STATS (SAFE)
====================================================== */
exports.getDashboardStats = async (req, res) => {
  try {
    const totalEmployees = await User.countDocuments({ role: "EMPLOYEE" });
    const latest = await getLatestAttendancePerEmployee();

    const stats = {
      totalEmployees,
      checkedInToday: latest.filter((r) => r.attendance.status === "CHECKED_IN")
        .length,
      inOfficeCount: latest.filter(
        (r) => r.attendance.status === "REACHED_OFFICE"
      ).length,
      checkedOutToday: latest.filter(
        (r) => r.attendance.status === "CHECKED_OUT"
      ).length,
      notCheckedIn:
        totalEmployees -
        latest.filter((r) =>
          ["CHECKED_IN", "REACHED_OFFICE", "CHECKED_OUT"].includes(
            r.attendance.status
          )
        ).length,
    };

    res.json({ success: true, data: stats });
  } catch (e) {
    res.status(500).json({ success: false, message: e.message });
  }
};
