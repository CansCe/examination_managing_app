// Input sanitization utilities to prevent NoSQL injection
import { ObjectId } from 'mongodb';

/**
 * Sanitize a string input to prevent NoSQL injection
 * Removes MongoDB operators and special characters
 */
export function sanitizeString(input) {
  if (typeof input !== 'string') {
    return String(input);
  }
  
  // Remove MongoDB operators that could be used for injection
  const dangerousPatterns = [
    /\$where/i,
    /\$ne/i,
    /\$gt/i,
    /\$gte/i,
    /\$lt/i,
    /\$lte/i,
    /\$in/i,
    /\$nin/i,
    /\$exists/i,
    /\$regex/i,
    /\$or/i,
    /\$and/i,
    /\$not/i,
    /\$nor/i,
    /\$expr/i,
    /\$jsonSchema/i,
    /\$text/i,
    /\$mod/i,
    /\$type/i,
    /\$all/i,
    /\$elemMatch/i,
    /\$size/i,
    /\$bitsAllSet/i,
    /\$bitsAnySet/i,
    /\$bitsAllClear/i,
    /\$bitsAnyClear/i,
  ];
  
  let sanitized = input.trim();
  
  // Check for dangerous patterns
  for (const pattern of dangerousPatterns) {
    if (pattern.test(sanitized)) {
      throw new Error('Invalid input: contains potentially dangerous characters');
    }
  }
  
  return sanitized;
}

/**
 * Sanitize username/email input
 */
export function sanitizeUsername(input) {
  if (!input || typeof input !== 'string') {
    throw new Error('Username must be a non-empty string');
  }
  
  const sanitized = sanitizeString(input);
  
  // Additional validation for username/email
  if (sanitized.length > 255) {
    throw new Error('Username is too long');
  }
  
  return sanitized;
}

/**
 * Sanitize password input
 */
export function sanitizePassword(input) {
  if (!input || typeof input !== 'string') {
    throw new Error('Password must be a non-empty string');
  }
  
  // Don't sanitize passwords too aggressively, but check for basic issues
  if (input.length > 1000) {
    throw new Error('Password is too long');
  }
  
  return input;
}

/**
 * Sanitize and validate MongoDB ObjectId
 */
export function sanitizeObjectId(id) {
  if (!id) {
    throw new Error('ID is required');
  }
  
  if (typeof id !== 'string') {
    id = String(id);
  }
  
  // Validate ObjectId format (24 hex characters)
  if (!/^[0-9a-fA-F]{24}$/.test(id)) {
    throw new Error('Invalid ID format');
  }
  
  try {
    return new ObjectId(id);
  } catch (error) {
    throw new Error('Invalid ObjectId');
  }
}

/**
 * Sanitize user ID (can be ObjectId or string)
 */
export function sanitizeUserId(id) {
  if (!id) {
    throw new Error('User ID is required');
  }
  
  if (typeof id !== 'string') {
    id = String(id);
  }
  
  // If it's a valid ObjectId, return it
  if (/^[0-9a-fA-F]{24}$/.test(id)) {
    try {
      return new ObjectId(id);
    } catch (error) {
      throw new Error('Invalid user ID format');
    }
  }
  
  // Otherwise, sanitize as string
  return sanitizeString(id);
}

/**
 * Sanitize query parameters for MongoDB queries
 */
export function sanitizeQuery(query) {
  if (!query || typeof query !== 'object') {
    return {};
  }
  
  const sanitized = {};
  
  for (const [key, value] of Object.entries(query)) {
    // Skip MongoDB operators in keys
    if (key.startsWith('$')) {
      continue;
    }
    
    if (typeof value === 'string') {
      sanitized[key] = sanitizeString(value);
    } else if (value instanceof ObjectId || ObjectId.isValid(value)) {
      sanitized[key] = value;
    } else if (typeof value === 'number' || typeof value === 'boolean') {
      sanitized[key] = value;
    } else if (Array.isArray(value)) {
      sanitized[key] = value.map(item => 
        typeof item === 'string' ? sanitizeString(item) : item
      );
    } else {
      sanitized[key] = value;
    }
  }
  
  return sanitized;
}

