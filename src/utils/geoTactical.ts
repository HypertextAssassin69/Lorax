/**
 * Tactical Search & Rescue (SAR) Geographic & Navigation Math Utilities
 */

const EARTH_RADIUS_METERS = 6371000;

/**
 * Calculates Haversine distance in meters between two coordinates
 */
export function calculateDistanceMeters(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return EARTH_RADIUS_METERS * c;
}

/**
 * Calculates initial compass bearing in degrees (0 - 360) from coord1 to coord2
 */
export function calculateBearing(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const phi1 = (lat1 * Math.PI) / 180;
  const phi2 = (lat2 * Math.PI) / 180;
  const lambdaDiff = ((lon2 - lon1) * Math.PI) / 180;

  const y = Math.sin(lambdaDiff) * Math.cos(phi2);
  const x =
    Math.cos(phi1) * Math.sin(phi2) -
    Math.sin(phi1) * Math.cos(phi2) * Math.cos(lambdaDiff);
  const theta = Math.atan2(y, x);

  const bearing = ((theta * 180) / Math.PI + 360) % 360;
  return bearing;
}

/**
 * Converts degrees to cardinal/intercardinal direction
 */
export function getCardinalDirection(bearing: number): string {
  const directions = [
    'N', 'NNE', 'NE', 'ENE',
    'E', 'ESE', 'SE', 'SSE',
    'S', 'SSW', 'SW', 'WSW',
    'W', 'WNW', 'NW', 'NNW',
  ];
  const index = Math.round(bearing / 22.5) % 16;
  return directions[index];
}

/**
 * Formats distance with human readable metric units
 */
export function formatDistance(meters: number): string {
  if (meters < 1000) {
    return `${Math.round(meters)} m`;
  }
  return `${(meters / 1000).toFixed(2)} km`;
}

/**
 * Formats compass bearing (e.g. "042° NE")
 */
export function formatBearing(bearing: number): string {
  const rounded = Math.round(bearing);
  const padded = rounded.toString().padStart(3, '0');
  const cardinal = getCardinalDirection(bearing);
  return `${padded}° ${cardinal}`;
}

/**
 * Estimates hiking/SAR walking time based on Tobler's hiking pace (~4.2 km/h flat SAR pace)
 */
export function estimatePaceTime(meters: number, speedKmh = 4.2): string {
  const hours = meters / (speedKmh * 1000);
  const minutes = Math.round(hours * 60);

  if (minutes < 1) return '< 1 min';
  if (minutes < 60) return `${minutes} min`;

  const hrs = Math.floor(minutes / 60);
  const remMin = minutes % 60;
  return `${hrs}h ${remMin}m`;
}
