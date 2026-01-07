// server.js
require("dotenv").config();
const express = require("express");
const http = require("http");
const socketIo = require("socket.io");
const cors = require("cors");
const connectDB = require("./config/db");
const User = require("./models/User");

// Initialize express app
const app = express();
const server = http.createServer(app);

// Socket.io setup with CORS
const io = socketIo(server, {
  cors: {
    origin: process.env.ALLOWED_ORIGINS.split(","),
    methods: ["GET", "POST"],
    credentials: true,
  },
});

// Connect to MongoDB
connectDB();

// CORS Middleware - MUST BE BEFORE ROUTES
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(",")
  : [
      "http://localhost:54821",
      "http://localhost:5173",
      "http://localhost:52743",
    ];

app.use(
  cors({
    origin: function (origin, callback) {
      // Allow requests with no origin (like mobile apps or Postman)
      if (!origin) return callback(null, true);

      if (
        allowedOrigins.indexOf(origin) !== -1 ||
        allowedOrigins.includes("*")
      ) {
        callback(null, true);
      } else {
        console.log(`🚫 CORS blocked origin: ${origin}`);
        callback(null, true); // Allow anyway for development
      }
    },
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
    credentials: true,
  })
);

// Body parser middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Make io accessible to routes
app.set("io", io);

// Routes
app.use("/api/auth", require("./routes/auth"));
app.use("/api/employee", require("./routes/employee"));
app.use("/api/admin", require("./routes/admin"));

// Root route
app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "EmpTracker Pro API - Employee Location Tracking System",
    version: "1.0.0",
    endpoints: {
      auth: "/api/auth",
      employee: "/api/employee",
      admin: "/api/admin",
    },
  });
});

// Health check route
app.get("/health", (req, res) => {
  res.json({
    success: true,
    status: "healthy",
    timestamp: new Date().toISOString(),
  });
});

// Socket.io connection handling
io.on("connection", (socket) => {
  console.log("🔌 New client connected:", socket.id);

  // Join admin room
  socket.on("join_admin", () => {
    socket.join("admin");
    console.log("👤 Admin joined:", socket.id);
  });

  // Join employee room
  socket.on("join_employee", (employeeId) => {
    socket.join(`employee_${employeeId}`);
    console.log(`👤 Employee ${employeeId} joined:`, socket.id);
  });

  // Broadcast location update
  socket.on("location_update", (data) => {
    io.to("admin").emit("location_updated", data);
    console.log("📍 Location updated:", data.employeeId);
  });

  // Disconnect
  socket.on("disconnect", () => {
    console.log("❌ Client disconnected:", socket.id);
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error("❌ Error:", err.message);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || "Server Error",
    error: process.env.NODE_ENV === "development" ? err : {},
  });
});

// 404 handler - MUST BE LAST
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Route not found",
  });
});

// Create default admin user
const createDefaultAdmin = async () => {
  try {
    const adminExists = await User.findOne({ role: "ADMIN" });

    if (!adminExists) {
      await User.create({
        name: process.env.DEFAULT_ADMIN_NAME || "Admin",
        email: process.env.DEFAULT_ADMIN_EMAIL || "admin@gmail.com",
        password: process.env.DEFAULT_ADMIN_PASSWORD || "Admin@123",
        role: "ADMIN",
      });
      console.log("✅ Default admin created");
      console.log(
        "📧 Email:",
        process.env.DEFAULT_ADMIN_EMAIL || "admin@gmail.com"
      );
      console.log(
        "🔑 Password:",
        process.env.DEFAULT_ADMIN_PASSWORD || "Admin@123"
      );
    }
  } catch (error) {
    console.error("❌ Error creating default admin:", error.message);
  }
};

// Start server
const PORT = process.env.PORT || 5000;

server.listen(PORT, async () => {
  console.log("\n🚀 ========================================");
  console.log(`🚀 EmpTracker Pro Server Running`);
  console.log(`🚀 ========================================`);
  console.log(`📡 Port: ${PORT}`);
  console.log(`🌍 Environment: ${process.env.NODE_ENV || "development"}`);
  console.log(
    `🗄️  Database: ${
      process.env.MONGODB_URI?.split("@")[1]?.split("/")[0] || "localhost"
    }`
  );
  console.log(`🏢 Office: ${process.env.OFFICE_NAME || "Office"}`);
  console.log(
    `📍 Location: ${process.env.OFFICE_LAT || "0"}, ${
      process.env.OFFICE_LNG || "0"
    }`
  );
  console.log(`🔗 Allowed Origins: ${allowedOrigins.join(", ")}`);
  console.log(`🚀 ========================================\n`);

  // Create default admin
  await createDefaultAdmin();
});

// Handle unhandled promise rejections
process.on("unhandledRejection", (err) => {
  console.error("❌ Unhandled Rejection:", err.message);
  server.close(() => process.exit(1));
});

// Handle uncaught exceptions
process.on("uncaughtException", (err) => {
  console.error("❌ Uncaught Exception:", err.message);
  process.exit(1);
});

module.exports = { app, server, io };
