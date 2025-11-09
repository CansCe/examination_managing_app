// Helper functions for MongoDB queries

import { ObjectId } from 'mongodb';

/**
 * Validate UUID format (for backward compatibility with encoded MongoDB IDs)
 */
export function isValidUuid(str) {
  if (!str || typeof str !== 'string') return false;
  // Sanitize: remove any whitespace and check length
  const sanitized = str.trim();
  if (sanitized.length > 36) return false; // UUID max length is 36
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(sanitized);
}

/**
 * Validate MongoDB ObjectId format
 */
export function isValidObjectId(str) {
  if (!str || typeof str !== 'string') return false;
  // Sanitize: remove any whitespace and check length
  const sanitized = str.trim();
  if (sanitized.length !== 24) return false; // ObjectId must be exactly 24 hex chars
  // Additional validation: only allow hex characters
  if (!/^[0-9a-fA-F]{24}$/.test(sanitized)) return false;
  return ObjectId.isValid(sanitized);
}

/**
 * Convert string to ObjectId (safe)
 */
export function toObjectId(str) {
  if (!str || typeof str !== 'string') return null;
  const sanitized = str.trim();
  if (ObjectId.isValid(sanitized) && /^[0-9a-fA-F]{24}$/.test(sanitized)) {
    return new ObjectId(sanitized);
  }
  return null;
}

/**
 * Sanitize and validate user ID (prevents NoSQL injection)
 * Returns sanitized ID or null if invalid
 */
export function sanitizeUserId(userId) {
  if (!userId || typeof userId !== 'string') return null;
  
  // Remove whitespace
  const sanitized = userId.trim();
  
  // Check for dangerous characters that could be used in NoSQL injection
  // MongoDB operators: $, ., [, ], {, }
  const dangerousChars = /[\$\.\[\]\{\}]/;
  if (dangerousChars.test(sanitized)) {
    console.warn(`⚠️ Potential NoSQL injection attempt detected: ${sanitized}`);
    return null;
  }
  
  // Validate format: must be either UUID or ObjectId
  if (isValidUuid(sanitized) || isValidObjectId(sanitized)) {
    return sanitized;
  }
  
  // If it's an encoded UUID (starts with 454d4150), allow it but validate format
  if (sanitized.includes('-') && sanitized.length <= 36) {
    // Check if it matches the encoded UUID pattern
    const parts = sanitized.split('-');
    if (parts.length === 5) {
      // Validate each part is hex
      const allHex = parts.every(part => /^[0-9a-fA-F]+$/.test(part));
      if (allHex) {
        return sanitized;
      }
    }
  }
  
  console.warn(`⚠️ Invalid user ID format: ${sanitized}`);
  return null;
}

/**
 * Sanitize and validate user role (prevents injection)
 */
export function sanitizeUserRole(role) {
  if (!role || typeof role !== 'string') return null;
  
  const sanitized = role.trim().toLowerCase();
  const validRoles = ['student', 'teacher', 'admin'];
  
  if (validRoles.includes(sanitized)) {
    return sanitized;
  }
  
  console.warn(`⚠️ Invalid user role: ${role}`);
  return null;
}

