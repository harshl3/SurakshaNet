import React, { useEffect, useState } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Circle, Polygon, Polyline, useMap, useMapEvents } from 'react-leaflet';
import L from 'leaflet';
import { useAuth } from '../context/AuthContext';
import { Camera, Shield, Eye, AlertTriangle, MapPin, Navigation, Compass, User, Phone, Lock, Building2, Radio, ArrowRight, Maximize2, Minimize2, RotateCcw, Crosshair } from 'lucide-react';
import { ThreeDMap } from './map/ThreeDMap';
import { MapCompass } from './map/MapCompass';
import { CameraDossierModal } from './CameraDossierModal';

// Helper to generate coordinates for a Field-of-View (FOV) sector wedge
const getFovPolygonCoordinates = (lat, lon, directionAngle = 0, radiusMeters = 80, fovAngleDegrees = 60) => {
  const numLat = parseFloat(lat);
  const numLon = parseFloat(lon);
  const numRadius = parseFloat(radiusMeters) || 80;
  const numDir = parseFloat(directionAngle) || 0;
  const numFov = parseFloat(fovAngleDegrees) || 60;

  if (isNaN(numLat) || isNaN(numLon) || numFov <= 0) return [];

  // Full 360-degree fisheye / omnidirectional view
  if (numFov >= 360) {
    const circlePoints = [];
    const metersPerLatDegree = 111320;
    const metersPerLonDegree = 111320 * Math.cos((numLat * Math.PI) / 180);
    for (let deg = 0; deg < 360; deg += 15) {
      const rad = (deg * Math.PI) / 180;
      const ptLat = numLat + (numRadius * Math.sin(rad)) / metersPerLatDegree;
      const ptLon = numLon + (numRadius * Math.cos(rad)) / metersPerLonDegree;
      circlePoints.push([ptLat, ptLon]);
    }
    circlePoints.push(circlePoints[0]);
    return circlePoints;
  }

  const startAngle = numDir - numFov / 2;
  const endAngle = numDir + numFov / 2;
  const step = Math.max(0.5, (endAngle - startAngle) / 8);

  const metersPerLatDegree = 111320;
  const metersPerLonDegree = 111320 * Math.cos((numLat * Math.PI) / 180);

  const points = [[numLat, numLon]];
  for (let a = startAngle; a <= endAngle + 0.001; a += step) {
    const rad = ((90 - a) * Math.PI) / 180;
    const ptLat = numLat + (numRadius * Math.sin(rad)) / metersPerLatDegree;
    const ptLon = numLon + (numRadius * Math.cos(rad)) / metersPerLonDegree;
    points.push([ptLat, ptLon]);
  }

  points.push([numLat, numLon]);
  return points;
};

// Official Police Station Pin Marker
const createPoliceStationIcon = () => {
  const html = `
    <div class="relative flex items-center justify-center filter drop-shadow-md hover:scale-110 transition-transform cursor-pointer">
      <img 
        src="/police-station-marker.png" 
        alt="Police Station Precinct" 
        class="w-[38px] h-[44px] object-contain drop-shadow-sm" 
      />
    </div>
  `;

  return L.divIcon({
    html: html,
    className: 'police-station-marker-pin',
    iconSize: [38, 44],
    iconAnchor: [19, 44],
    popupAnchor: [0, -44],
  });
};

// Custom SVG Marker for Camera Node with Rotating Direction Arrow & Satellite Circle
const createCameraIcon = (status, verificationStatus, directionAngle = 0, isSelected = false) => {
  let color = '#10B981'; // Green for Active
  if (status === 'OFFLINE' || verificationStatus === 'REJECTED') color = '#CF4500'; // Signal Orange / Red
  if (status === 'UNDER_MAINTENANCE' || verificationStatus === 'PENDING') color = '#F79E1B'; // Amber

  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40" width="${isSelected ? '46' : '38'}" height="${isSelected ? '46' : '38'}">
      ${isSelected ? `<circle cx="20" cy="20" r="19" fill="none" stroke="#141413" stroke-width="2.5" stroke-dasharray="3 2"/>` : ''}
      <!-- Direction Indicator Arrow -->
      <g transform="rotate(${directionAngle}, 20, 20)">
        <polygon points="20,2 25,11 15,11" fill="${color}"/>
        <circle cx="20" cy="20" r="14" fill="none" stroke="${color}" stroke-width="1.5" stroke-opacity="0.7"/>
      </g>
      <!-- Center Camera Hub -->
      <circle cx="20" cy="20" r="9" fill="#FFFFFF" stroke="#141413" stroke-width="2"/>
      <circle cx="20" cy="20" r="5" fill="${color}"/>
      ${verificationStatus === 'PENDING' ? '<circle cx="27" cy="13" r="3.5" fill="#F79E1B" stroke="#FFFFFF" stroke-width="1"/>' : ''}
    </svg>
  `;

  const size = isSelected ? 46 : 38;
  return L.divIcon({
    html: svg,
    className: 'custom-camera-marker',
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
  });
};

// Crime Scene Pin: Ink Black & Signal Orange Target
const createCrimeSceneIcon = () => {
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 44 44" width="46" height="46">
      <circle cx="22" cy="22" r="20" fill="#CF4500" fill-opacity="0.2" stroke="#CF4500" stroke-width="2.5"/>
      <circle cx="22" cy="22" r="12" fill="#141413"/>
      <polygon points="22,7 26,16 35,17 28,24 30,33 22,28 14,33 16,24 9,17 18,16" fill="#F37338"/>
      <circle cx="22" cy="22" r="3" fill="#FFFFFF"/>
    </svg>
  `;

  return L.divIcon({
    html: svg,
    className: 'crime-scene-marker',
    iconSize: [46, 46],
    iconAnchor: [23, 23],
  });
};

// Live GPS Marker
const createLiveGpsIcon = () => {
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40" width="40" height="40">
      <circle cx="20" cy="20" r="16" fill="#141413" fill-opacity="0.2" stroke="#141413" stroke-width="2"/>
      <circle cx="20" cy="20" r="9" fill="#141413"/>
      <circle cx="20" cy="20" r="3.5" fill="#F37338"/>
    </svg>
  `;

  return L.divIcon({
    html: svg,
    className: 'live-gps-marker',
    iconSize: [40, 40],
    iconAnchor: [20, 20],
  });
};

// Dedicated Map Picker Target Pin Icon
const createPickerPinIcon = () => {
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 46 46" width="46" height="46">
      <circle cx="23" cy="23" r="18" fill="#CF4500" fill-opacity="0.25">
        <animate attributeName="r" values="14;22;14" dur="2s" repeatCount="indefinite"/>
        <animate attributeName="fill-opacity" values="0.35;0.08;0.35" dur="2s" repeatCount="indefinite"/>
      </circle>
      <circle cx="23" cy="23" r="10" fill="#141413" stroke="#FFFFFF" stroke-width="2.5"/>
      <circle cx="23" cy="23" r="4.5" fill="#CF4500"/>
      <!-- Crosshairs -->
      <line x1="23" y1="3" x2="23" y2="10" stroke="#CF4500" stroke-width="2" stroke-linecap="round"/>
      <line x1="23" y1="36" x2="23" y2="43" stroke="#CF4500" stroke-width="2" stroke-linecap="round"/>
      <line x1="3" y1="23" x2="10" y2="23" stroke="#CF4500" stroke-width="2" stroke-linecap="round"/>
      <line x1="36" y1="23" x2="43" y2="23" stroke="#CF4500" stroke-width="2" stroke-linecap="round"/>
    </svg>
  `;

  return L.divIcon({
    html: svg,
    className: 'picker-target-pin',
    iconSize: [46, 46],
    iconAnchor: [23, 23],
  });
};

// Invalidate Leaflet map size on mount, fullscreen toggle, and container layout change safely
const MapInvalidator = ({ isFullscreen }) => {
  const map = useMap();

  useEffect(() => {
    try {
      map.invalidateSize();
    } catch (e) {
      // ignore
    }
    const t1 = setTimeout(() => {
      try { map.invalidateSize(); } catch (e) {}
    }, 150);
    const t2 = setTimeout(() => {
      try { map.invalidateSize(); } catch (e) {}
    }, 400);

    let rafId = null;
    const resizeObserver = new ResizeObserver(() => {
      if (rafId) cancelAnimationFrame(rafId);
      rafId = requestAnimationFrame(() => {
        try {
          map.invalidateSize();
        } catch (e) {
          // container might be unmounting
        }
      });
    });

    const container = map.getContainer();
    if (container) {
      resizeObserver.observe(container);
    }

    return () => {
      clearTimeout(t1);
      clearTimeout(t2);
      if (rafId) cancelAnimationFrame(rafId);
      resizeObserver.disconnect();
    };
  }, [map, isFullscreen]);

  return null;
};

// Floating Fullscreen Expand/Minimize Control
const FullscreenControl = ({ isFullscreen, onToggleFullscreen }) => {
  const map = useMap();

  const handleToggle = (e) => {
    e.preventDefault();
    e.stopPropagation();
    onToggleFullscreen();
    setTimeout(() => map.invalidateSize(), 100);
    setTimeout(() => map.invalidateSize(), 300);
  };

  return (
    <div className="leaflet-top leaflet-right" style={{ zIndex: 1000, pointerEvents: 'auto' }}>
      <div className="leaflet-control m-2.5 sm:m-3">
        <button
          type="button"
          onClick={handleToggle}
          title={isFullscreen ? "Exit Fullscreen (ESC)" : "Expand Fullscreen Map"}
          className={`flex items-center gap-1.5 px-3 py-1.5 sm:py-2 rounded-full font-medium text-xs tracking-tight shadow-mc-card transition-all active:scale-95 border cursor-pointer ${
            isFullscreen 
              ? 'bg-[#CF4500] text-white hover:bg-[#B53C00] border-[#CF4500] ring-2 ring-white'
              : 'bg-white/95 backdrop-blur-md text-[#141413] hover:bg-[#141413] hover:text-white border-[#E5DFD9]'
          }`}
        >
          {isFullscreen ? (
            <>
              <Minimize2 className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-white shrink-0" />
              <span className="font-bold text-[11px] sm:text-xs">Exit Fullscreen</span>
            </>
          ) : (
            <>
              <Maximize2 className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-[#CF4500] shrink-0" />
              <span className="font-bold text-[11px] sm:text-xs">Expand Map</span>
            </>
          )}
        </button>
      </div>
    </div>
  );
};

// Auto pan to newly picked location
const MapPanToSelected = ({ selectedLocation, active }) => {
  const map = useMap();
  useEffect(() => {
    if (active && selectedLocation?.lat && selectedLocation?.lng) {
      map.panTo([selectedLocation.lat, selectedLocation.lng], { animate: true, duration: 0.5 });
    }
  }, [selectedLocation?.lat, selectedLocation?.lng, active, map]);
  return null;
};

// Smoothly fly and focus on camera when clicked or selected
const MapFocusOnCamera = ({ camera }) => {
  const map = useMap();
  useEffect(() => {
    if (camera?.latitude && camera?.longitude) {
      const numLat = parseFloat(camera.latitude);
      const numLng = parseFloat(camera.longitude);
      if (!isNaN(numLat) && !isNaN(numLng)) {
        map.flyTo([numLat, numLng], 16.5, { animate: true, duration: 0.8 });
      }
    }
  }, [camera, map]);
  return null;
};

// Smoothly fly to target coordinates upon explicit user action (e.g. Live GPS or Reset to Nagpur)
const MapFlyToTarget = ({ target, trigger }) => {
  const map = useMap();
  useEffect(() => {
    if (trigger > 0 && target && target.length >= 2) {
      map.flyTo([target[0], target[1]], target[2] || 16, { animate: true, duration: 0.9 });
    }
  }, [trigger, target, map]);
  return null;
};

// Auto-adjust map viewport when explicit focusKey triggers or crime scene changes
const AutoBounds = ({ crimeLocation, autoFit = true, focusKey }) => {
  const map = useMap();
  const lastTargetRef = React.useRef({ lat: null, lng: null, focusKey: null });

  useEffect(() => {
    const targetLat = parseFloat(crimeLocation?.lat);
    const targetLng = parseFloat(crimeLocation?.lng);

    if (!isNaN(targetLat) && !isNaN(targetLng)) {
      const isNewCoords = lastTargetRef.current.lat !== targetLat || lastTargetRef.current.lng !== targetLng;
      const isExplicitFocus = focusKey !== undefined && focusKey !== null && lastTargetRef.current.focusKey !== focusKey;

      if (isExplicitFocus || (isNewCoords && autoFit) || lastTargetRef.current.lat === null) {
        lastTargetRef.current = { lat: targetLat, lng: targetLng, focusKey };
        try {
          map.flyTo([targetLat, targetLng], 16, { animate: true, duration: 0.9 });
        } catch (e) {
          map.setView([targetLat, targetLng], 16);
        }
      }
    }
  }, [crimeLocation?.lat, crimeLocation?.lng, autoFit, focusKey, map]);

  return null;
};

// Map click listener that supports all caller argument signatures safely
const MapClickListener = ({ onMapClick }) => {
  useMapEvents({
    click(e) {
      if (onMapClick) {
        const lat = Math.round(e.latlng.lat * 100000) / 100000;
        const lng = Math.round(e.latlng.lng * 100000) / 100000;
        const locObj = { lat, lng, latitude: lat, longitude: lng };
        try {
          // Pass (lat, lng, locObj) so both fn(lat, lng) and fn(locObj) work seamlessly
          onMapClick(lat, lng, locObj);
        } catch (err) {
          console.error('onMapClick handler error:', err);
        }
      }
    },
  });
  return null;
};

export const CameraMap = ({ 
  cameras = [], 
  stations = [],
  center = [21.1458, 79.0882], // Default open in Nagpur region (Zero Mile / Sitabuldi HQ)
  zoom = 13.5, 
  crimeLocation = null,
  searchRadius = 500,
  onSelectCamera,
  onMapClick,
  selectedLocation = null,
  selectedCameraId = null,
  interactivePicker = false,
  autoFit = false,
  allowFullscreen = true,
  focusKey = null,
  defaultViewMode = '2d'
}) => {
  const { user } = useAuth();
  const userRole = typeof user?.role === 'object' ? user?.role?.name : user?.role;
  const isSurveyor = userRole === 'ROLE_SURVEY_PERSON';

  const [isFullscreen, setIsFullscreen] = useState(false);
  const [viewMode, setViewMode] = useState(defaultViewMode); // '2d' | '3d'
  const [dossierCamera, setDossierCamera] = useState(null);
  const [liveLocation, setLiveLocation] = useState(null);
  const [isLocating, setIsLocating] = useState(false);
  const [flyTarget, setFlyTarget] = useState(null);
  const [flyTrigger, setFlyTrigger] = useState(0);

  const handleGetLiveLocation = () => {
    if (!navigator.geolocation) {
      alert('Geolocation is not supported by your browser.');
      return;
    }
    setIsLocating(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const lat = Math.round(pos.coords.latitude * 100000) / 100000;
        const lng = Math.round(pos.coords.longitude * 100000) / 100000;
        const loc = { lat, lng };
        setLiveLocation(loc);
        setIsLocating(false);
        setFlyTarget([lat, lng, 16.5]);
        setFlyTrigger(prev => prev + 1);
      },
      (err) => {
        console.warn('Live location error:', err);
        setIsLocating(false);
        alert('Unable to retrieve your live GPS location. Please check browser location permissions.');
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    );
  };

  const handleResetNagpur = () => {
    setLiveLocation(null);
    setFlyTarget([21.1458, 79.0882, 13.5]);
    setFlyTrigger(prev => prev + 1);
  };

  // Synchronize dossierCamera when selectedCameraId changes
  useEffect(() => {
    if (selectedCameraId && cameras.length > 0) {
      const found = cameras.find(c => c.id === selectedCameraId);
      if (found) {
        setDossierCamera(found);
      }
    }
  }, [selectedCameraId, cameras]);

  const handleSelectCamera = (cam) => {
    setDossierCamera(cam);
    if (onSelectCamera) onSelectCamera(cam);
  };

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Escape' && isFullscreen) {
        setIsFullscreen(false);
      }
    };
    if (isFullscreen) {
      document.body.style.overflow = 'hidden';
      window.addEventListener('keydown', handleKeyDown);
    } else {
      document.body.style.overflow = '';
    }
    return () => {
      document.body.style.overflow = '';
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, [isFullscreen]);

  const defaultStations = stations.length > 0 ? stations : [
    { id: 105, stationCode: 'PS-NGP-01', stationName: 'Nagpur Police Commissionerate HQ', latitude: 21.1524, longitude: 79.0801, address: 'Civil Lines, Nagpur', contactNumber: '+91-712-2560300', jurisdictionZone: 'Nagpur City HQ' },
    { id: 106, stationCode: 'PS-NGP-02', stationName: 'Sitabuldi Police Station', latitude: 21.1458, longitude: 79.0882, address: 'Main Road, Sitabuldi, Nagpur', contactNumber: '+91-712-2522000', jurisdictionZone: 'Central Nagpur' },
    { id: 107, stationCode: 'PS-AMR-01', stationName: 'Amravati City Police Commissionerate', latitude: 20.9320, longitude: 77.7523, address: 'Camp, Amravati', contactNumber: '+91-721-2551000', jurisdictionZone: 'Amravati Precinct' },
    { id: 101, stationCode: 'PS-DEL-01', stationName: 'Delhi Police Central HQ (ITO)', latitude: 28.6280, longitude: 77.2410, address: 'ITO, New Delhi', contactNumber: '+91-11-23490000', jurisdictionZone: 'Central Delhi' }
  ];

  const isValidLat = (val) => typeof val === 'number' && !isNaN(val) && val >= -90 && val <= 90;
  const isValidLng = (val) => typeof val === 'number' && !isNaN(val) && val >= -180 && val <= 180;

  const safeCenterLat = isValidLat(center?.[0]) ? center[0] : 21.1458;
  const safeCenterLng = isValidLng(center?.[1]) ? center[1] : 79.0882;
  const safeCenter = [safeCenterLat, safeCenterLng];

  const validSelectedLoc = selectedLocation && isValidLat(selectedLocation.lat) && isValidLng(selectedLocation.lng) ? selectedLocation : null;
  const validCrimeLoc = crimeLocation && isValidLat(crimeLocation.lat) && isValidLng(crimeLocation.lng) ? crimeLocation : null;

  return (
    <div 
      className={
        isFullscreen 
          ? 'fixed inset-0 z-[9999] w-screen h-screen rounded-none border-0 shadow-2xl bg-[#F3F0EE] overflow-hidden' 
          : `w-full h-full ${interactivePicker ? 'min-h-[220px] cursor-crosshair' : 'min-h-[340px]'} relative isolate rounded-[28px] sm:rounded-[36px] overflow-hidden border border-[#E5DFD9] shadow-mc-card bg-[#F3F0EE]`
      }
    >
      {/* UNIFIED TOP BAR (2D Leaflet Mode): Non-overlapping responsive header */}
      {viewMode === '2d' && (
        <div className="absolute top-2.5 inset-x-2.5 sm:top-3 sm:inset-x-3 z-[1000] pointer-events-none flex items-center justify-between gap-1.5 sm:gap-2">
          {/* Left: Tactical 2D Badge */}
          <div className="pointer-events-auto flex items-center gap-1.5 sm:gap-2 bg-[#141413]/90 backdrop-blur-md px-2.5 sm:px-3.5 py-1 sm:py-1.5 rounded-full text-white border border-white/10 shadow-lg text-[10px] sm:text-[11px] font-semibold shrink-0">
            <img src="/police-logo.png" alt="Police Shield" className="w-3.5 h-3.5 object-contain shrink-0" />
            <span className="font-bold tracking-tight">2D GRID</span>
            <span className="text-[9px] font-mono text-[#F37338] bg-[#F37338]/20 px-1.5 py-0.5 rounded-full border border-[#F37338]/30">
              NAGPUR
            </span>
          </div>

          {/* Right: Mode Switcher & Fullscreen Expand */}
          <div className="pointer-events-auto flex items-center gap-1 sm:gap-1.5 shrink-0 ml-auto">
            {!interactivePicker && (
              <div className="flex items-center bg-[#141413]/90 backdrop-blur-md p-0.5 rounded-full border border-white/15 shadow-lg">
                <button
                  type="button"
                  onClick={() => setViewMode('2d')}
                  className={`px-2 sm:px-2.5 py-1 rounded-full text-[10px] sm:text-[11px] font-bold transition-all ${
                    viewMode === '2d'
                      ? 'bg-white text-[#141413] shadow-sm'
                      : 'text-white/70 hover:text-white'
                  }`}
                >
                  2D
                </button>
                <button
                  type="button"
                  onClick={() => setViewMode('3d')}
                  className={`flex items-center gap-1 px-2 sm:px-2.5 py-1 rounded-full text-[10px] sm:text-[11px] font-bold transition-all ${
                    viewMode === '3d'
                      ? 'bg-[#CF4500] text-white shadow-sm'
                      : 'text-white/70 hover:text-white'
                  }`}
                >
                  <span className="w-1.5 h-1.5 rounded-full bg-[#10B981] animate-pulse"></span>
                  <span>3D</span>
                </button>
              </div>
            )}

            {allowFullscreen && (
              <button
                type="button"
                onClick={() => setIsFullscreen(!isFullscreen)}
                title={isFullscreen ? "Exit Fullscreen (ESC)" : "Expand Fullscreen Map"}
                className={`flex items-center gap-1 px-2.5 py-1 rounded-full font-medium text-[10px] sm:text-[11px] shadow-mc-card transition-all active:scale-95 border cursor-pointer ${
                  isFullscreen 
                    ? 'bg-[#CF4500] text-white hover:bg-[#B53C00] border-[#CF4500]'
                    : 'bg-white/95 backdrop-blur-md text-[#141413] hover:bg-[#141413] hover:text-white border-[#E5DFD9]'
                }`}
              >
                {isFullscreen ? (
                  <>
                    <Minimize2 className="w-3 h-3 text-white shrink-0" />
                    <span className="hidden sm:inline font-bold">Exit</span>
                  </>
                ) : (
                  <>
                    <Maximize2 className="w-3 h-3 text-[#CF4500] shrink-0" />
                    <span className="hidden sm:inline font-bold">Expand</span>
                  </>
                )}
              </button>
            )}
          </div>
        </div>
      )}

      {viewMode === '3d' ? (
        <ThreeDMap
          cameras={cameras}
          stations={defaultStations}
          center={safeCenter}
          zoom={zoom}
          crimeLocation={validCrimeLoc}
          searchRadius={searchRadius}
          onSelectCamera={handleSelectCamera}
          onMapClick={onMapClick}
          selectedLocation={validSelectedLoc}
          liveLocation={liveLocation}
          onGetLiveLocation={handleGetLiveLocation}
          isLocating={isLocating}
          selectedCameraId={selectedCameraId}
          interactivePicker={interactivePicker}
          autoFit={autoFit}
          allowFullscreen={allowFullscreen}
          isFullscreen={isFullscreen}
          onToggleFullscreen={() => setIsFullscreen(!isFullscreen)}
          focusKey={focusKey}
          viewMode={viewMode}
          onViewModeChange={setViewMode}
        />
      ) : (
        <MapContainer 
          center={safeCenter} 
          zoom={zoom} 
          scrollWheelZoom={true} 
          attributionControl={false}
          zoomControl={false}
          className="w-full h-full"
        >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>'
          url="https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png"
        />

        {/* Dynamic viewport & size recalculations on mount and fullscreen toggle */}
        <MapInvalidator isFullscreen={isFullscreen} />
        <MapPanToSelected selectedLocation={validSelectedLoc} active={interactivePicker} />
        <MapFocusOnCamera camera={dossierCamera} />
        <MapFlyToTarget target={flyTarget} trigger={flyTrigger} />

        <AutoBounds 
          crimeLocation={crimeLocation} 
          autoFit={autoFit} 
          focusKey={focusKey}
        />

        {interactivePicker && <MapClickListener onMapClick={onMapClick} />}

        {/* Location Marker - ONLY when interactivePicker is active or when user requests Live GPS */}
        {((interactivePicker && validSelectedLoc) || liveLocation) && (() => {
          const displayLoc = liveLocation || validSelectedLoc;
          const isLive = Boolean(liveLocation && !interactivePicker);
          return (
            <>
              <Marker 
                position={[displayLoc.lat, displayLoc.lng]} 
                icon={interactivePicker ? createPickerPinIcon() : createLiveGpsIcon()}
              >
                <Popup>
                  <div className="p-3 text-[#141413] text-xs font-semibold space-y-1.5 min-w-[210px]">
                    <div className="flex items-center gap-1.5 text-[#141413] font-mono text-[11px] font-bold border-b border-[#E5DFD9] pb-1">
                      <span className={`w-2 h-2 rounded-full ${interactivePicker ? 'bg-[#CF4500]' : 'bg-[#10B981]'} animate-ping`}></span>
                      <span>{interactivePicker ? 'SELECTED REGISTRATION POINT' : 'LIVE PATROL GPS FIX'}</span>
                    </div>
                    <p className="text-[#696969] font-mono text-[11px] leading-relaxed">
                      Lat: <span className="text-[#141413] font-bold">{Number(displayLoc.lat).toFixed(5)}</span><br/>
                      Lng: <span className="text-[#141413] font-bold">{Number(displayLoc.lng).toFixed(5)}</span>
                    </p>
                    {isLive && (
                      <p className="text-[10px] text-[#10B981] font-sans font-semibold pt-0.5">
                        ● Real-time Live Position Active
                      </p>
                    )}
                    {interactivePicker && (
                      <p className="text-[10px] text-[#CF4500] font-sans font-semibold pt-0.5">
                        ✓ Location locked (Click anywhere to relocate)
                      </p>
                    )}
                  </div>
                </Popup>
              </Marker>
              <Circle
                center={[displayLoc.lat, displayLoc.lng]}
                radius={interactivePicker ? 60 : 150}
                pathOptions={{
                  color: interactivePicker ? '#CF4500' : '#10B981',
                  fillColor: interactivePicker ? '#CF4500' : '#10B981',
                  fillOpacity: interactivePicker ? 0.12 : 0.1,
                  weight: 2,
                  dashArray: '4, 4'
                }}
              />
            </>
          );
        })()}

        {/* Police Station Headquarters Markers */}
        {defaultStations.map((st) => {
          if (!st.latitude || !st.longitude) return null;

          return (
            <Marker
              key={`station-${st.id || st.stationCode}`}
              position={[st.latitude, st.longitude]}
              icon={createPoliceStationIcon()}
            >
              <Popup>
                <div className="p-3.5 text-[#141413] min-w-[260px] space-y-2">
                  <div className="flex items-center justify-between border-b border-[#E5DFD9] pb-1.5">
                    <span className="font-bold text-[#141413] font-mono text-xs flex items-center gap-1.5">
                      <img src="/police-station-marker.png" alt="Police Precinct" className="w-4 h-4 object-contain shrink-0" />
                      {st.stationCode}
                    </span>
                    <span className="text-[9px] font-bold px-2 py-0.5 rounded-full bg-[#EAF7EE] text-[#0A7334] border border-[#BDE7CA] font-mono">
                      CCTNS VERIFIED
                    </span>
                  </div>

                  <div>
                    <h4 className="font-bold text-sm text-[#141413] leading-snug">{st.stationName}</h4>
                    <p className="text-xs text-[#696969] mt-0.5 flex items-center gap-1">
                      <MapPin className="w-3.5 h-3.5 text-[#9A3A0A] shrink-0" />
                      {st.address || st.jurisdictionZone || 'Metropolitan Station'}
                    </p>
                  </div>

                  <div className="p-2.5 rounded-[16px] bg-[#F3F0EE] border border-[#E5DFD9] text-xs space-y-1">
                    <p className="text-[11px] text-[#696969] flex justify-between">
                      <span>Jurisdiction:</span>
                      <strong className="text-[#141413]">{st.jurisdictionZone || 'Central Zone'}</strong>
                    </p>
                    <p className="font-semibold text-[#141413] flex items-center gap-1 font-mono pt-1 border-t border-[#E5DFD9] text-[11px]">
                      <Phone className="w-3.5 h-3.5 text-[#CF4500]" />
                      Helpline: <strong>{st.contactNumber || '+91 11 100'}</strong>
                    </p>
                  </div>
                </div>
              </Popup>
            </Marker>
          );
        })}

        {/* Crime Scene Location, Radius, and Connective Orbital Trajectory Lines */}
        {validCrimeLoc && (
          <>
            <Marker position={[validCrimeLoc.lat, validCrimeLoc.lng]} icon={createCrimeSceneIcon()}>
              <Popup>
                <div className="p-3 text-[#141413] min-w-[220px] space-y-1.5">
                  <p className="font-bold text-[#CF4500] flex items-center gap-1 text-xs uppercase tracking-wider">
                    <span className="w-2 h-2 rounded-full bg-[#CF4500]"></span>
                    Crime Scene Incident Target
                  </p>
                  <p className="text-sm font-semibold text-[#141413]">{validCrimeLoc.name || 'Incident Focal Point'}</p>
                  <p className="text-[11px] text-[#696969] font-mono">Coords: {validCrimeLoc.lat}, {validCrimeLoc.lng}</p>
                  <p className="text-[11px] text-[#CF4500] font-bold bg-[#FDF0EE] p-1.5 rounded-full border border-[#F8C6BC] text-center">
                    Investigation Radius: {searchRadius}m
                  </p>
                </div>
              </Popup>
            </Marker>
            <Circle
              center={[validCrimeLoc.lat, validCrimeLoc.lng]}
              radius={searchRadius}
              pathOptions={{
                color: '#CF4500',
                fillColor: '#F37338',
                fillOpacity: 0.1,
                weight: 2,
                dashArray: '6, 6'
              }}
            />

            {/* Connective Orbital Trajectory Lines between Crime Scene and Nearby CCTV Nodes */}
            {cameras.map((cam) => {
              if (!cam.latitude || !cam.longitude) return null;
              return (
                <Polyline
                  key={`orbit-${cam.id || cam.cameraCode}`}
                  positions={[
                    [validCrimeLoc.lat, validCrimeLoc.lng],
                    [cam.latitude, cam.longitude]
                  ]}
                  pathOptions={{
                    color: '#F37338',
                    weight: 1.2,
                    opacity: 0.45,
                    dashArray: '3, 6'
                  }}
                />
              );
            })}
          </>
        )}

        {/* CCTV Cameras & FOV Cones */}
        {cameras.map((cam) => {
          if (!cam.latitude || !cam.longitude) return null;

          const isSelected = selectedCameraId === cam.id;
          const fovPolygon = getFovPolygonCoordinates(
            cam.latitude,
            cam.longitude,
            cam.directionAngle || 0,
            cam.coverageRadiusMeters || 80,
            cam.fovAngle || 60
          );

          const coneColor = cam.verificationStatus === 'APPROVED' 
            ? (cam.cameraStatus === 'ACTIVE' ? '#10B981' : '#CF4500') 
            : '#F79E1B';

          return (
            <React.Fragment key={cam.id || cam.cameraCode}>
              {/* Field of View (FOV) Sector Cone Polygon */}
              {fovPolygon.length > 0 && (
                <Polygon
                  positions={fovPolygon}
                  pathOptions={{
                    color: coneColor,
                    fillColor: coneColor,
                    fillOpacity: 0.15,
                    weight: 1.5,
                    dashArray: cam.verificationStatus === 'PENDING' ? '4, 4' : null
                  }}
                />
              )}

              {/* Camera Marker with Orientation Arrow - Triggers CCTV Node Dossier */}
              <Marker
                position={[cam.latitude, cam.longitude]}
                icon={createCameraIcon(cam.cameraStatus, cam.verificationStatus, cam.directionAngle || 0, isSelected)}
                eventHandlers={{
                  click: () => handleSelectCamera(cam)
                }}
              />
            </React.Fragment>
          );
        })}
      </MapContainer>
      )}

      {/* 2D Tactical Controls & Live Location Option */}
      {viewMode === '2d' && !interactivePicker && (
        <div className="absolute bottom-2.5 left-2.5 sm:bottom-3 sm:left-3 z-[1000] pointer-events-auto flex items-center gap-1 sm:gap-1.5 bg-[#141413]/90 backdrop-blur-md px-2.5 py-1 rounded-full border border-white/15 shadow-xl text-white text-xs max-w-[calc(100%-80px)] overflow-x-auto no-scrollbar">
          <button
            type="button"
            onClick={handleResetNagpur}
            title="Reset Map to Nagpur Hub"
            className="flex items-center gap-1 px-2 py-0.5 rounded-full bg-white/10 hover:bg-[#CF4500] hover:text-white transition-all active:scale-95 text-[10px] sm:text-[11px] font-medium shrink-0"
          >
            <RotateCcw className="w-2.5 h-2.5 text-[#F37338]" />
            <span>HQ</span>
          </button>

          <div className="h-3 w-px bg-white/20 shrink-0"></div>

          <button
            type="button"
            onClick={handleGetLiveLocation}
            title="Acquire Live GPS Patrol Location"
            className="flex items-center gap-1 px-2 py-0.5 rounded-full bg-white/10 hover:bg-[#10B981] hover:text-white transition-all active:scale-95 text-[10px] sm:text-[11px] font-medium text-white/90 shrink-0"
          >
            <Navigation className={`w-2.5 h-2.5 ${isLocating ? 'animate-spin text-[#F37338]' : 'text-[#10B981]'}`} />
            <span>{isLocating ? 'GPS...' : 'Live GPS'}</span>
          </button>
        </div>
      )}

      {/* 2D Tactical Surveillance Compass Overlay */}
      {viewMode === '2d' && !interactivePicker && (
        <div className="absolute bottom-2.5 right-2.5 sm:bottom-3 sm:right-3 z-[1000] pointer-events-auto scale-75 sm:scale-85 origin-bottom-right">
          <MapCompass
            bearing={0}
            interactive={false}
            title="Police Tactical Grid • True North (000° N)"
          />
        </div>
      )}

      {/* Universal CCTV Node Dossier Modal across all maps */}
      {dossierCamera && (
        <CameraDossierModal
          camera={dossierCamera}
          onClose={() => {
            setDossierCamera(null);
            if (onSelectCamera) onSelectCamera(null);
          }}
          isSurveyor={isSurveyor}
        />
      )}
    </div>
  );
};
