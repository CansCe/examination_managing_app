// Helper functions for MongoDB queries

import { ObjectId } from 'mongodb';

/**
 * Validate UUID format (for backward compatibility with encoded MongoDB IDs)
 */
export function isValidUuid(str) {
  if (!str) return false;
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  return uuidRegex.test(str);
}

/**
 * Validate MongoDB ObjectId format
 */
export function isValidObjectId(str) {
  if (!str) return false;
  return ObjectId.isValid(str);
}

/**
 * Convert string to ObjectId
 */
export function toObjectId(str) {
  if (!str) return null;
  if (ObjectId.isValid(str)) {
    return new ObjectId(str);
  }
  return null;
}

