export const errorHandler = (err, req, res, next) => {
  console.error('\n╔══════════════════════════════════════════════════════════╗');
  console.error('║  ✗ MAIN API SERVICE - Error                           ║');
  console.error('╚══════════════════════════════════════════════════════════╝');
  console.error('Error:', err);
  console.error('Path:', req.originalUrl);
  console.error('Method:', req.method);

  // MongoDB duplicate key error
  if (err.code === 11000) {
    return res.status(400).json({
      success: false,
      service: 'MAIN API SERVICE',
      error: 'Duplicate entry',
      message: 'A record with this value already exists'
    });
  }

  // MongoDB validation error
  if (err.name === 'ValidationError') {
    return res.status(400).json({
      success: false,
      service: 'MAIN API SERVICE',
      error: 'Validation Error',
      message: err.message,
      details: err.errors
    });
  }

  // Invalid ObjectId
  if (err.name === 'BSONError' || err.message?.includes('ObjectId')) {
    return res.status(400).json({
      success: false,
      service: 'MAIN API SERVICE',
      error: 'Invalid ID format',
      message: 'The provided ID is not valid'
    });
  }

  // Default error
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';

  res.status(statusCode).json({
    success: false,
    service: 'MAIN API SERVICE',
    error: message,
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
};

export const notFound = (req, res, next) => {
  res.status(404).json({
    success: false,
    service: 'MAIN API SERVICE',
    error: 'Not Found',
    message: `Route ${req.originalUrl} not found`
  });
};

