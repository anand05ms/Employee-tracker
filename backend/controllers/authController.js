// controllers/authController.js
const User = require("../models/User");
const jwt = require("jsonwebtoken");

// Generate JWT token
const generateToken = (user) => {
  return jwt.sign(
    {
      id: user._id,
      role: user.role, // 🔥 CRITICAL FIX
    },
    process.env.JWT_SECRET,
    {
      expiresIn: process.env.JWT_EXPIRE,
    }
  );
};

// @desc    Register new user (Employee)
// @route   POST /api/auth/register
// @access  Public
exports.register = async (req, res) => {
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

    // Create user
    const user = await User.create({
      name,
      email,
      password,
      phone,
      department,
      employeeId,
      role: "EMPLOYEE",
    });

    // Generate token
    const token = generateToken(user);

    res.status(201).json({
      success: true,
      message: "User registered successfully",
      data: {
        user: user.toSafeObject(),
        token,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error registering user",
      error: error.message,
    });
  }
};

// @desc    Login user
// @route   POST /api/auth/login
// @access  Public
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate input
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Please provide email and password",
      });
    }

    // Find user and include password
    const user = await User.findOne({ email }).select("+password");

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid credentials",
      });
    }

    // Check if user is active
    if (!user.isActive) {
      return res.status(401).json({
        success: false,
        message: "Your account has been deactivated. Please contact admin.",
      });
    }

    // Check password
    const isPasswordCorrect = await user.comparePassword(password);

    if (!isPasswordCorrect) {
      return res.status(401).json({
        success: false,
        message: "Invalid credentials",
      });
    }

    // Generate token
    const token = generateToken(user);

    res.status(200).json({
      success: true,
      message: "Login successful",
      data: {
        user: user.toSafeObject(),
        token,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error logging in",
      error: error.message,
    });
  }
};

// @desc    Get current logged in user
// @route   GET /api/auth/me
// @access  Private
exports.getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user.id);

    res.status(200).json({
      success: true,
      data: {
        user: user.toSafeObject(),
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error fetching user data",
      error: error.message,
    });
  }
};

// @desc    Update user profile
// @route   PUT /api/auth/profile
// @access  Private
exports.updateProfile = async (req, res) => {
  try {
    const { name, phone, department } = req.body;

    const user = await User.findByIdAndUpdate(
      req.user.id,
      { name, phone, department },
      { new: true, runValidators: true }
    );

    res.status(200).json({
      success: true,
      message: "Profile updated successfully",
      data: {
        user: user.toSafeObject(),
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error updating profile",
      error: error.message,
    });
  }
};
