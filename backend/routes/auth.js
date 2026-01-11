// routes/auth.js
const express = require("express");
const router = express.Router();
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const { protect } = require("../middleware/auth");
const User = require("../models/User");

console.log("🔍 Auth routes LOADED ✅");

// =====================================================
// 🔑 HELPER: Generate JWT
// =====================================================
const generateToken = (user) => {
  return jwt.sign({ id: user._id, role: user.role }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE || "7d",
  });
};

// =====================================================
// 📝 REGISTER (EMPLOYEE)
// POST /api/auth/register
// =====================================================
router.post("/register", async (req, res) => {
  try {
    const { name, email, password, phone, department, employeeId } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: "Name, email and password are required",
      });
    }

    // Check existing email
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: "User already exists with this email",
      });
    }

    // Create user
    const user = await User.create({
      name,
      email,
      password, // hashed by model pre-save
      phone,
      department,
      employeeId,
      role: "EMPLOYEE",
    });

    const token = generateToken(user);

    console.log("✅ REGISTER SUCCESS:", user.email);

    res.status(201).json({
      success: true,
      message: "Registration successful",
      data: {
        token,
        user: {
          id: user._id,
          name: user.name,
          email: user.email,
          role: user.role,
        },
      },
    });
  } catch (error) {
    console.error("❌ REGISTER ERROR:", error.message);
    res.status(500).json({
      success: false,
      message: "Registration failed",
    });
  }
});

// =====================================================
// 🔐 LOGIN
// POST /api/auth/login
// =====================================================
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Email and password required",
      });
    }

    const user = await User.findOne({ email }).select("+password");

    if (!user) {
      return res.status(400).json({
        success: false,
        message: "Invalid credentials",
      });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({
        success: false,
        message: "Invalid credentials",
      });
    }

    const token = generateToken(user);

    console.log("✅ LOGIN SUCCESS:", user.email);

    res.json({
      success: true,
      data: {
        token,
        user: {
          id: user._id,
          name: user.name,
          email: user.email,
          role: user.role,
        },
      },
    });
  } catch (error) {
    console.error("❌ LOGIN ERROR:", error.message);
    res.status(500).json({
      success: false,
      message: "Login failed",
    });
  }
});

// =====================================================
// 👤 GET CURRENT USER
// GET /api/auth/me
// =====================================================
router.get("/me", protect, async (req, res) => {
  res.json({
    success: true,
    data: {
      user: req.user,
    },
  });
});

// =====================================================
// 🔄 CHANGE PASSWORD
// PUT /api/auth/change-password
// =====================================================
router.put("/change-password", protect, async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;

    const user = await User.findById(req.user.id).select("+password");

    const isMatch = await bcrypt.compare(oldPassword, user.password);
    if (!isMatch) {
      return res.status(400).json({
        success: false,
        message: "Old password incorrect",
      });
    }

    user.password = newPassword;
    await user.save();

    res.json({
      success: true,
      message: "Password updated successfully",
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Password update failed",
    });
  }
});

module.exports = router;
