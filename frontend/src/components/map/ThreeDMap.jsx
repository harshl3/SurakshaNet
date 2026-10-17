import React, { useEffect, useRef, useState, useCallback } from 'react';
import maplibregl from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import { useAuth } from '../../context/AuthContext';
import { MapCompass } from './MapCompass';
import { 
  Compass, 
  MapPin, 
  RotateCcw,
  Clock,
  Shield,
  Sun,
  Moon,
  Globe,
  Maximize2,
  Minimize2,
  Camera,
  Navigation,
  Phone,
  User,
  Lock,
  X,
  ExternalLink,
  Radio,
  Eye,
  Crosshair,
  Plus,
  Minus
} from 'lucide-react';

/**
 * ============================================================================
 * FUTURE-READY 3D SURVEILLANCE SCHEMA (SPECIFICATION STUB)
 * ============================================================================
 * @typedef {Object} FutureCamera3DProps
 * @property {number} [cameraHeight] - Mounting height above ground level (AGL) in meters
 * @property {number} [directionBearing] - 3D azimuth heading (0° = North, 90° = East)
 * @property {number} [tiltAngle] - Vertical pitch depression angle (-90° down to +90° up)
 * @property {number} [fieldOfView] - Horizontal & vertical optical cone aperture in degrees
 * @property {number} [coverageRadius] - Max effective identification depth in meters
 * @property {boolean} [obstacleDetection] - Raycast occlusion against 3D building geometries
 */

// Vidarbha Region (Nagpur Hub) Reference Coordinates
const VIDARBHA_CONFIG = {
  center: [79.0882, 21.1458], // [lng, lat] Sitabuldi / Nagpur Police Zone
  defaultZoom: 15.2,
  defaultPitch: 55, // Perspective tilt for realistic 3D depth
  defaultBearing: -15, // Isometric angle
  maxPitch: 75,
  minPitch: 0,
  bounds: [
    [75.8, 18.5], // Southwest boundary [lng, lat]
    [81.2, 22.3]  // Northeast boundary [lng, lat]
  ]
};

// Map Style Specifications
const MAP_STYLES = {
  satellite: {
    id: 'satellite',
    label: '3D Satellite',
    icon: Globe,
    styleUrl: 'https://tiles.openfreemap.org/styles/liberty',
    isSatellite: true,
  },
  urban: {
    id: 'urban',
    label: '3D Daylight',
    icon: Sun,
    styleUrl: 'https://tiles.openfreemap.org/styles/liberty',
    isSatellite: false,
  },
  night: {
    id: 'night',
    label: 'Tactical Night',
    icon: Moon,
    styleUrl: 'https://tiles.openfreemap.org/styles/liberty',
    isSatellite: false,
  }
};

// Helper: Calculate polygon coordinates for Field-of-View (FOV) wedge in GeoJSON [lng, lat] format
// Identical formula to Leaflet 2D getFovPolygonCoordinates
const getFovGeoJsonCoordinates = (lat, lon, directionAngle = 0, radiusMeters = 80, fovAngleDegrees = 60) => {
  const numLat = parseFloat(lat);
  const numLon = parseFloat(lon);
  const numRadius = parseFloat(radiusMeters) || 80;
  const numDir = parseFloat(directionAngle) || 0;
  const numFov = parseFloat(fovAngleDegrees) || 60;

  if (isNaN(numLat) || isNaN(numLon) || numFov <= 0) return null;

  const metersPerLatDegree = 111320;
  const metersPerLonDegree = 111320 * Math.cos((numLat * Math.PI) / 180);

  // Full 360-degree fisheye / omnidirectional view
  if (numFov >= 360) {
    const coords = [];
    for (let deg = 0; deg <= 360; deg += 15) {
      const rad = (deg * Math.PI) / 180;
      const ptLat = numLat + (numRadius * Math.sin(rad)) / metersPerLatDegree;
      const ptLon = numLon + (numRadius * Math.cos(rad)) / metersPerLonDegree;
      coords.push([ptLon, ptLat]);
    }
    return [coords];
  }

  const startAngle = numDir - numFov / 2;
  const endAngle = numDir + numFov / 2;
  const step = Math.max(0.5, (endAngle - startAngle) / 12);

  const coords = [[numLon, numLat]];
  for (let a = startAngle; a <= endAngle + 0.001; a += step) {
    const rad = ((90 - a) * Math.PI) / 180;
    const ptLat = numLat + (numRadius * Math.sin(rad)) / metersPerLatDegree;
    const ptLon = numLon + (numRadius * Math.cos(rad)) / metersPerLonDegree;
    coords.push([ptLon, ptLat]);
  }
  coords.push([numLon, numLat]);
  return [coords];
};

// Helper: Generate circle coordinates for Crime Scene radius in GeoJSON [lng, lat]
const getCircleGeoJsonCoordinates = (lat, lon, radiusMeters = 500) => {
  const numLat = parseFloat(lat);
  const numLon = parseFloat(lon);
  const numRadius = parseFloat(radiusMeters) || 500;
  if (isNaN(numLat) || isNaN(numLon)) return null;

  const metersPerLatDegree = 111320;
  const metersPerLonDegree = 111320 * Math.cos((numLat * Math.PI) / 180);
  const coords = [];
  for (let deg = 0; deg <= 360; deg += 6) {
    const rad = (deg * Math.PI) / 180;
    const ptLat = numLat + (numRadius * Math.sin(rad)) / metersPerLatDegree;
    const ptLon = numLon + (numRadius * Math.cos(rad)) / metersPerLonDegree;
    coords.push([ptLon, ptLat]);
  }
  return [coords];
};

export const ThreeDMap = ({
  cameras = [],
  stations = [],
  center,
  zoom = 15.2,
  crimeLocation = null,
  searchRadius = 500,
  onSelectCamera,
  onMapClick,
  selectedLocation = null,
  liveLocation = null,
  onGetLiveLocation,
  isLocating = false,
  selectedCameraId = null,
  interactivePicker = false,
  autoFit = true,
  allowFullscreen = true,
  isFullscreen = false,
  onToggleFullscreen,
  focusKey = null,
  viewMode = '3d',
  onViewModeChange
}) => {
  const { user } = useAuth();
  const userRole = typeof user?.role === 'object' ? user?.role?.name : user?.role;
  const isSurveyor = userRole === 'ROLE_SURVEY_PERSON';

  const mapContainerRef = useRef(null);
  const mapRef = useRef(null);
  const markersRef = useRef([]);
  const activePopupRef = useRef(null);
  // Style Mode: 'satellite' | 'urban' | 'night'
  const [styleMode, setStyleMode] = useState('satellite');
  const [currentPitch, setCurrentPitch] = useState(VIDARBHA_CONFIG.defaultPitch);
  const [currentBearing, setCurrentBearing] = useState(VIDARBHA_CONFIG.defaultBearing);
  const [realtimeClock, setRealtimeClock] = useState('');
  const [internalLiveLoc, setInternalLiveLoc] = useState(null);
  const [internalIsLocating, setInternalIsLocating] = useState(false);

  const effectiveLiveLoc = liveLocation || internalLiveLoc;
  const effectiveIsLocating = isLocating || internalIsLocating;

  // Validate coordinates
  const isValidLat = (val) => typeof val === 'number' && !isNaN(val) && val >= -90 && val <= 90;
  const isValidLng = (val) => typeof val === 'number' && !isNaN(val) && val >= -180 && val <= 180;

  // Real-time ticking clock (IST)
  useEffect(() => {
    const updateTime = () => {
      const now = new Date();
      const timeStr = now.toLocaleTimeString('en-IN', { 
        hour12: false, 
        hour: '2-digit', 
        minute: '2-digit', 
        second: '2-digit' 
      });
      setRealtimeClock(`${timeStr} IST`);
    };
    updateTime();
    const interval = setInterval(updateTime, 1000);
    return () => clearInterval(interval);
  }, []);

  // Determine center coordinates - Defaults to Nagpur region [79.0882, 21.1458]
  const getInitialCenter = useCallback(() => {
    if (crimeLocation && isValidLat(crimeLocation.lat) && isValidLng(crimeLocation.lng)) {
      return [parseFloat(crimeLocation.lng), parseFloat(crimeLocation.lat)];
    }
    if (center && isValidLat(center[0]) && isValidLng(center[1])) {
      return [parseFloat(center[1]), parseFloat(center[0])];
    }
    return VIDARBHA_CONFIG.center; // [79.0882, 21.1458] (Sitabuldi / Nagpur Central HQ)
  }, [crimeLocation, center]);

  // Update GeoJSON Layers (FOV Cones, Crime Radius, and Connective Trajectory Lines)
  const updateMapLayers = useCallback(() => {
    const map = mapRef.current;
    if (!map) return;

    // 1. Build FOV Cones GeoJSON
    const fovFeatures = [];
    cameras.forEach((cam) => {
      if (!cam.latitude || !cam.longitude) return;

      const fixedDirection = parseFloat(cam.directionAngle) || 0;
      const radius = parseFloat(cam.coverageRadiusMeters) || 80;
      const fov = parseFloat(cam.fovAngle) || 60;

      const coords = getFovGeoJsonCoordinates(
        cam.latitude,
        cam.longitude,
        fixedDirection,
        radius,
        fov
      );

      if (coords) {
        const coneColor = cam.verificationStatus === 'APPROVED' 
          ? (cam.cameraStatus === 'ACTIVE' ? '#10B981' : '#CF4500') 
          : '#F79E1B';

        fovFeatures.push({
          type: 'Feature',
          geometry: { type: 'Polygon', coordinates: coords },
          properties: { 
            id: cam.id || cam.cameraCode, 
            color: coneColor,
            status: cam.cameraStatus,
            verificationStatus: cam.verificationStatus
          }
        });
      }
    });

    const fovSource = map.getSource('camera-fovs');
    if (fovSource) {
      fovSource.setData({ type: 'FeatureCollection', features: fovFeatures });
    }

    // 2. Build Crime Scene Investigation Radius & Radar Trajectory Lines
    const crimeFeatures = [];
    const validCrime = crimeLocation && isValidLat(crimeLocation.lat) && isValidLng(crimeLocation.lng);
    if (validCrime) {
      const circleCoords = getCircleGeoJsonCoordinates(crimeLocation.lat, crimeLocation.lng, searchRadius || 500);
      if (circleCoords) {
        crimeFeatures.push({
          type: 'Feature',
          geometry: { type: 'Polygon', coordinates: circleCoords },
          properties: { type: 'crime-radius' }
        });
      }

      // Trajectory lines connecting crime scene to all CCTV nodes
      cameras.forEach((cam) => {
        if (!cam.latitude || !cam.longitude) return;
        crimeFeatures.push({
          type: 'Feature',
          geometry: {
            type: 'LineString',
            coordinates: [
              [parseFloat(crimeLocation.lng), parseFloat(crimeLocation.lat)],
              [parseFloat(cam.longitude), parseFloat(cam.latitude)]
            ]
          },
          properties: { type: 'radar-line' }
        });
      });
    }

    const crimeSource = map.getSource('crime-scene-data');
    if (crimeSource) {
      crimeSource.setData({ type: 'FeatureCollection', features: crimeFeatures });
    }
  }, [cameras, crimeLocation, searchRadius]);

  // 1. Initialize MapLibre GL Instance
  useEffect(() => {
    if (!mapContainerRef.current) return;

    const initialCenter = getInitialCenter();

    const map = new maplibregl.Map({
      container: mapContainerRef.current,
      style: MAP_STYLES[styleMode].styleUrl,
      center: initialCenter,
      zoom: zoom || VIDARBHA_CONFIG.defaultZoom,
      pitch: VIDARBHA_CONFIG.defaultPitch,
      bearing: VIDARBHA_CONFIG.defaultBearing,
      maxPitch: VIDARBHA_CONFIG.maxPitch,
      minPitch: VIDARBHA_CONFIG.minPitch,
      attributionControl: false
    });

    map.on('pitch', () => setCurrentPitch(Math.round(map.getPitch())));
    map.on('rotate', () => setCurrentBearing(Math.round(map.getBearing())));
    map.on('error', (e) => console.warn('[MapLibre GL Notice]', e?.error?.message || e));

    setTimeout(() => { try { map.resize(); } catch(e){} }, 80);
    setTimeout(() => { try { map.resize(); } catch(e){} }, 300);
    setTimeout(() => { try { map.resize(); } catch(e){} }, 700);

    map.on('load', () => {
      try {
        map.resize();

        // 1A. High-Resolution Aerial Satellite Layer
        if (!map.getSource('esri-satellite')) {
          map.addSource('esri-satellite', {
            type: 'raster',
            tiles: [
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
            ],
            tileSize: 256,
            maxzoom: 19
          });

          const layers = map.getStyle().layers;
          let firstSymbolLayerId;
          for (let i = 0; i < layers.length; i++) {
            if (layers[i].type === 'symbol') {
              firstSymbolLayerId = layers[i].id;
              break;
            }
          }

          map.addLayer(
            {
              id: 'esri-satellite-layer',
              type: 'raster',
              source: 'esri-satellite',
              layout: {
                visibility: styleMode === 'satellite' ? 'visible' : 'none'
              },
              paint: {
                'raster-opacity': 0.94,
                'raster-contrast': 0.1,
                'raster-saturation': 0.15
              }
            },
            firstSymbolLayerId
          );
        }

        // 1B. Crime Scene Radar & Connective Trajectory Sources & Layers (Placed on Ground)
        if (!map.getSource('crime-scene-data')) {
          map.addSource('crime-scene-data', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });

          // Investigation Radius Circle Fill (Identical to Leaflet #F37338 with 0.1 opacity)
          map.addLayer({
            id: 'crime-radius-fill',
            type: 'fill',
            source: 'crime-scene-data',
            filter: ['==', '$type', 'Polygon'],
            paint: {
              'fill-color': '#F37338',
              'fill-opacity': 0.1
            }
          });

          // Investigation Radius Dashed Outer Ring (Identical to Leaflet #CF4500 dashed ring)
          map.addLayer({
            id: 'crime-radius-line',
            type: 'line',
            source: 'crime-scene-data',
            filter: ['==', '$type', 'Polygon'],
            paint: {
              'line-color': '#CF4500',
              'line-width': 2.2,
              'line-dasharray': [3, 2]
            }
          });

          // Dotted Orbital Connective Lines connecting Crime Scene to Cameras
          map.addLayer({
            id: 'crime-radar-lines',
            type: 'line',
            source: 'crime-scene-data',
            filter: ['==', '$type', 'LineString'],
            paint: {
              'line-color': '#F37338',
              'line-width': 1.4,
              'line-dasharray': [2, 3],
              'line-opacity': 0.55
            }
          });
        }

        // 1C. CCTV Surveillance FOV Cones Layer (Placed on Ground)
        if (!map.getSource('camera-fovs')) {
          map.addSource('camera-fovs', {
            type: 'geojson',
            data: { type: 'FeatureCollection', features: [] }
          });

          // FOV Sector Wedge Fill (Soft translucent mint green #10B981)
          map.addLayer({
            id: 'camera-fovs-fill',
            type: 'fill',
            source: 'camera-fovs',
            paint: {
              'fill-color': ['get', 'color'],
              'fill-opacity': 0.18
            }
          });

          // FOV Sector Wedge Outline (Crisp stroke matching camera status)
          map.addLayer({
            id: 'camera-fovs-outline',
            type: 'line',
            source: 'camera-fovs',
            paint: {
              'line-color': ['get', 'color'],
              'line-width': 1.8,
              'line-opacity': 0.85
            }
          });
        }

        // 1D. 3D Building Extrusions Layer
        const layers = map.getStyle().layers;
        let labelLayerId;
        for (let i = 0; i < layers.length; i++) {
          if (layers[i].type === 'symbol' && layers[i].layout && layers[i].layout['text-field']) {
            labelLayerId = layers[i].id;
            break;
          }
        }

        if (map.getSource('openmaptiles') && !map.getLayer('3d-buildings')) {
          map.addLayer(
            {
              id: '3d-buildings',
              source: 'openmaptiles',
              'source-layer': 'building',
              type: 'fill-extrusion',
              minzoom: 13,
              paint: {
                'fill-extrusion-color': [
                  'interpolate',
                  ['linear'],
                  ['get', 'render_height'],
                  0, styleMode === 'night' ? '#1E293B' : (styleMode === 'satellite' ? '#E2E8F0' : '#CBD5E1'),
                  20, styleMode === 'night' ? '#0F172A' : (styleMode === 'satellite' ? '#94A3B8' : '#94A3B8'),
                  45, styleMode === 'night' ? '#0A0F1D' : (styleMode === 'satellite' ? '#64748B' : '#64748B')
                ],
                'fill-extrusion-height': [
                  'interpolate',
                  ['linear'],
                  ['zoom'],
                  13, 0,
                  14.5, ['coalesce', ['get', 'render_height'], ['get', 'height'], 15]
                ],
                'fill-extrusion-base': [
                  'interpolate',
                  ['linear'],
                  ['zoom'],
                  13, 0,
                  14.5, ['coalesce', ['get', 'render_min_height'], ['get', 'min_height'], 0]
                ],
                'fill-extrusion-opacity': styleMode === 'satellite' ? 0.78 : 0.88
              }
            },
            labelLayerId
          );
        }

        // 1E. Sun Angle & Ambient Lighting
        try {
          map.setLight({
            anchor: 'viewport',
            color: styleMode === 'night' ? '#3B82F6' : '#FFF7ED',
            intensity: styleMode === 'night' ? 0.35 : 0.65,
            position: [1.2, 210, 35]
          });
        } catch (e) {}

        // Populate GeoJSON features immediately on map load
        updateMapLayers();
      } catch (err) {
        console.warn('MapLibre 3D Realistic setup note:', err);
      }
    });

    map.on('styledata', () => {
      updateMapLayers();
    });

    mapRef.current = map;

    const handleRotate = () => {
      if (mapRef.current) {
        setCurrentBearing(mapRef.current.getBearing());
      }
    };
    const handlePitch = () => {
      if (mapRef.current) {
        setCurrentPitch(Math.round(mapRef.current.getPitch()));
      }
    };

    map.on('rotate', handleRotate);
    map.on('pitch', handlePitch);

    const resizeObserver = new ResizeObserver(() => {
      if (mapRef.current) mapRef.current.resize();
    });
    if (mapContainerRef.current) resizeObserver.observe(mapContainerRef.current);

    return () => {
      resizeObserver.disconnect();
      map.off('rotate', handleRotate);
      map.off('pitch', handlePitch);
      map.remove();
      mapRef.current = null;
    };
  }, []);

  // 2. Dynamic Style Switching (Satellite, Urban, Night)
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !map.isStyleLoaded()) return;

    try {
      const satLayer = map.getLayer('esri-satellite-layer');
      if (satLayer) {
        map.setLayoutProperty(
          'esri-satellite-layer',
          'visibility',
          styleMode === 'satellite' ? 'visible' : 'none'
        );
      }

      const bldgLayer = map.getLayer('3d-buildings');
      if (bldgLayer) {
        map.setPaintProperty('3d-buildings', 'fill-extrusion-color', [
          'interpolate',
          ['linear'],
          ['get', 'render_height'],
          0, styleMode === 'night' ? '#1E293B' : (styleMode === 'satellite' ? '#E2E8F0' : '#CBD5E1'),
          20, styleMode === 'night' ? '#0F172A' : (styleMode === 'satellite' ? '#94A3B8' : '#94A3B8'),
          45, styleMode === 'night' ? '#0A0F1D' : (styleMode === 'satellite' ? '#64748B' : '#64748B')
        ]);
        map.setPaintProperty('3d-buildings', 'fill-extrusion-opacity', styleMode === 'satellite' ? 0.75 : 0.88);
      }

      map.setLight({
        anchor: 'viewport',
        color: styleMode === 'night' ? '#3B82F6' : '#FFF7ED',
        intensity: styleMode === 'night' ? 0.35 : 0.65,
        position: [1.2, 210, 35]
      });

      updateMapLayers();
    } catch (e) {
      console.warn('Style switch dynamic update note:', e);
    }
  }, [styleMode, updateMapLayers]);

  // 3. Interactive Map Click (Registration Picker & Blank Space Dismissal)
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    const handleMapClick = (e) => {
      if (interactivePicker && onMapClick) {
        const lat = Math.round(e.lngLat.lat * 100000) / 100000;
        const lng = Math.round(e.lngLat.lng * 100000) / 100000;
        onMapClick(lat, lng, { lat, lng, latitude: lat, longitude: lng });
      } else {
        // Dismiss active popup when clicking on empty map terrain
        if (activePopupRef.current) {
          activePopupRef.current.remove();
          activePopupRef.current = null;
        }
      }
    };

    map.on('click', handleMapClick);
    return () => map.off('click', handleMapClick);
  }, [interactivePicker, onMapClick]);

  // 4. Update Layers when cameras, crimeLocation, or searchRadius change
  useEffect(() => {
    updateMapLayers();
  }, [cameras, crimeLocation, searchRadius, updateMapLayers]);

  // 5. Render Identical 2D/3D CCTV Markers & Crime Scene Pin
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    markersRef.current.forEach(marker => marker.remove());
    markersRef.current = [];

    // Helper: Create Camera Node Marker (Exact SVG replica from Leaflet 2D)
    const createCameraEl = (cam) => {
      const isSelected = selectedCameraId === cam.id;
      let color = '#10B981'; // Green for Active
      if (cam.cameraStatus === 'OFFLINE' || cam.verificationStatus === 'REJECTED') color = '#CF4500';
      if (cam.cameraStatus === 'UNDER_MAINTENANCE' || cam.verificationStatus === 'PENDING') color = '#F79E1B';

      // Authentic, static orientation angle from database
      const dirAngle = cam.directionAngle || 0;
      const size = isSelected ? 46 : 38;

      const el = document.createElement('div');
      el.className = 'custom-camera-marker cursor-pointer transition-transform duration-150 hover:scale-115 select-none';
      el.style.width = `${size}px`;
      el.style.height = `${size}px`;
      el.style.pointerEvents = 'auto';

      el.innerHTML = `
        <div style="width:${size}px;height:${size}px;display:flex;align-items:center;justify-content:center;">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40" width="${size}" height="${size}">
            ${isSelected ? `<circle cx="20" cy="20" r="19" fill="none" stroke="#141413" stroke-width="2.5" stroke-dasharray="3 2"/>` : ''}
            <!-- Direction Indicator Arrow -->
            <g transform="rotate(${dirAngle}, 20, 20)">
              <polygon points="20,2 25,11 15,11" fill="${color}"/>
              <circle cx="20" cy="20" r="14" fill="none" stroke="${color}" stroke-width="1.5" stroke-opacity="0.7"/>
            </g>
            <!-- Center Camera Hub: White base, black rim, color status dot -->
            <circle cx="20" cy="20" r="9" fill="#FFFFFF" stroke="#141413" stroke-width="2"/>
            <circle cx="20" cy="20" r="5" fill="${color}"/>
            ${cam.verificationStatus === 'PENDING' ? '<circle cx="27" cy="13" r="3.5" fill="#F79E1B" stroke="#FFFFFF" stroke-width="1"/>' : ''}
          </svg>
        </div>
      `;

      return el;
    };

    // 5A. Mount CCTV Camera Markers
    cameras.forEach((cam) => {
      if (!cam.latitude || !cam.longitude) return;

      const el = createCameraEl(cam);

      const marker = new maplibregl.Marker({ element: el })
        .setLngLat([parseFloat(cam.longitude), parseFloat(cam.latitude)])
        .addTo(map);

      // Clean, single click handler: focuses camera in 3D and triggers CCTV Node Dossier Modal directly across all maps
      el.addEventListener('click', (e) => {
        e.stopPropagation();
        e.preventDefault();
        map.flyTo({
          center: [parseFloat(cam.longitude), parseFloat(cam.latitude)],
          zoom: 16.5,
          pitch: 55,
          bearing: parseFloat(cam.directionAngle) || 0,
          duration: 900,
          essential: true
        });
        if (onSelectCamera) onSelectCamera(cam);
      });

      markersRef.current.push(marker);
    });

    // 5B. Mount Police Station Headquarters Markers
    const defaultStations = stations.length > 0 ? stations : [
      { id: 105, stationCode: 'PS-NGP-01', stationName: 'Nagpur Police Commissionerate HQ', latitude: 21.1524, longitude: 79.0801, address: 'Civil Lines, Nagpur', contactNumber: '+91-712-2560300', jurisdictionZone: 'Nagpur City HQ' },
      { id: 106, stationCode: 'PS-NGP-02', stationName: 'Sitabuldi Police Station', latitude: 21.1458, longitude: 79.0882, address: 'Main Road, Sitabuldi, Nagpur', contactNumber: '+91-712-2522000', jurisdictionZone: 'Central Nagpur' },
      { id: 107, stationCode: 'PS-AMR-01', stationName: 'Amravati City Police Commissionerate', latitude: 20.9320, longitude: 77.7523, address: 'Camp, Amravati', contactNumber: '+91-721-2551000', jurisdictionZone: 'Amravati Precinct' }
    ];

    defaultStations.forEach((st) => {
      if (!st.latitude || !st.longitude) return;

      const el = document.createElement('div');
      el.className = 'police-station-marker-pin cursor-pointer transition-transform duration-150 hover:scale-115';
      el.style.pointerEvents = 'auto';
      el.innerHTML = `
        <img 
          src="/police-station-marker.png" 
          alt="${st.stationName}" 
          style="width:38px;height:44px;object-fit:contain;filter:drop-shadow(0 4px 6px rgba(0,0,0,0.35));" 
        />
      `;

      const popup = new maplibregl.Popup({ offset: [0, -22], maxWidth: '320px', closeButton: true, closeOnClick: false })
        .setLngLat([parseFloat(st.longitude), parseFloat(st.latitude)])
        .setHTML(`
          <div style="font-family:inherit;min-width:240px;padding:4px;color:#141413;">
            <div style="display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid #E5DFD9;padding-bottom:6px;margin-bottom:8px;">
              <span style="font-family:monospace;font-weight:700;font-size:12px;color:#141413;">🏢 ${st.stationCode}</span>
              <span style="background:#EAF7EE;color:#0A7334;border:1px solid #BDE7CA;padding:2px 8px;border-radius:9999px;font-weight:700;font-size:10px;">CCTNS VERIFIED</span>
            </div>
            <div style="font-weight:700;font-size:14px;line-height:1.2;">${st.stationName}</div>
            <div style="color:#696969;font-size:11px;margin-top:2px;">📍 ${st.address || st.jurisdictionZone || 'Vidarbha Command HQ'}</div>
            <div style="background:#F3F0EE;border:1px solid #E5DFD9;padding:8px;border-radius:12px;margin-top:8px;font-size:11px;">
              <div style="color:#696969;">Jurisdiction: <strong style="color:#141413;">${st.jurisdictionZone || 'Central Vidarbha'}</strong></div>
              <div style="margin-top:4px;padding-top:4px;border-top:1px solid #E5DFD9;font-family:monospace;">
                📞 Helpline: <strong style="color:#CF4500;">${st.contactNumber || '+91 712 100'}</strong>
              </div>
            </div>
          </div>
        `);

      const marker = new maplibregl.Marker({ element: el, anchor: 'bottom' })
        .setLngLat([parseFloat(st.longitude), parseFloat(st.latitude)])
        .addTo(map);

      el.addEventListener('click', (e) => {
        e.stopPropagation();
        e.preventDefault();
        if (activePopupRef.current) {
          activePopupRef.current.remove();
          activePopupRef.current = null;
        }
        popup.addTo(map);
        activePopupRef.current = popup;
      });

      markersRef.current.push(marker);
    });

    // 5C. Mount Crime Scene Pin (Identical SVG to Leaflet 2D createCrimeSceneIcon)
    if (crimeLocation && isValidLat(crimeLocation.lat) && isValidLng(crimeLocation.lng)) {
      const el = document.createElement('div');
      el.className = 'crime-scene-target-node cursor-pointer';
      el.style.pointerEvents = 'auto';
      el.innerHTML = `
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 44 44" width="46" height="46">
          <circle cx="22" cy="22" r="20" fill="#CF4500" fill-opacity="0.2" stroke="#CF4500" stroke-width="2.5"/>
          <circle cx="22" cy="22" r="12" fill="#141413"/>
          <polygon points="22,7 26,16 35,17 28,24 30,33 22,28 14,33 16,24 9,17 18,16" fill="#F37338"/>
          <circle cx="22" cy="22" r="3" fill="#FFFFFF"/>
        </svg>
      `;

      const popup = new maplibregl.Popup({ offset: 18, maxWidth: '280px', closeButton: true, closeOnClick: false })
        .setLngLat([parseFloat(crimeLocation.lng), parseFloat(crimeLocation.lat)])
        .setHTML(`
          <div style="font-family:inherit;min-width:210px;padding:4px;color:#141413;">
            <div style="color:#CF4500;font-weight:700;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;display:flex;align-items:center;gap:4px;">
              <span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:#CF4500;"></span>
              Crime Scene Incident Target
            </div>
            <div style="font-weight:700;font-size:13px;margin-top:4px;">${crimeLocation.name || 'Incident Focal Point'}</div>
            <div style="font-size:11px;color:#696969;font-family:monospace;margin-top:2px;">Coords: ${crimeLocation.lat}, ${crimeLocation.lng}</div>
            <div style="background:#FDF0EE;border:1px solid #F8C6BC;color:#CF4500;padding:6px;border-radius:9999px;font-size:11px;font-weight:700;text-align:center;margin-top:6px;">
              Investigation Radius: ${searchRadius}m
            </div>
          </div>
        `);

      const marker = new maplibregl.Marker({ element: el })
        .setLngLat([parseFloat(crimeLocation.lng), parseFloat(crimeLocation.lat)])
        .addTo(map);

      el.addEventListener('click', (e) => {
        e.stopPropagation();
        e.preventDefault();
        if (activePopupRef.current) {
          activePopupRef.current.remove();
          activePopupRef.current = null;
        }
        popup.addTo(map);
        activePopupRef.current = popup;
      });

      markersRef.current.push(marker);
    }

    // 5D. Mount Selected Location Pin - When interactivePicker is active OR when user requests Live GPS
    const activeLoc = (interactivePicker && selectedLocation) || effectiveLiveLoc;
    if (activeLoc && isValidLat(activeLoc.lat) && isValidLng(activeLoc.lng)) {
      const isLive = Boolean(effectiveLiveLoc && !interactivePicker);
      const el = document.createElement('div');
      el.className = 'selected-patrol-marker cursor-pointer';
      el.style.pointerEvents = 'auto';

      if (interactivePicker) {
        el.innerHTML = `
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 46 46" width="46" height="46">
            <circle cx="23" cy="23" r="18" fill="#CF4500" fill-opacity="0.3"/>
            <circle cx="23" cy="23" r="10" fill="#141413" stroke="#FFFFFF" stroke-width="2.5"/>
            <circle cx="23" cy="23" r="4.5" fill="#CF4500"/>
            <line x1="23" y1="3" x2="23" y2="10" stroke="#CF4500" stroke-width="2.5" stroke-linecap="round"/>
            <line x1="23" y1="36" x2="23" y2="43" stroke="#CF4500" stroke-width="2.5" stroke-linecap="round"/>
            <line x1="3" y1="23" x2="10" y2="23" stroke="#CF4500" stroke-width="2.5" stroke-linecap="round"/>
            <line x1="36" y1="23" x2="43" y2="23" stroke="#CF4500" stroke-width="2.5" stroke-linecap="round"/>
          </svg>
        `;
      } else {
        el.innerHTML = `
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 42 42" width="42" height="42">
            <circle cx="21" cy="21" r="18" fill="#10B981" fill-opacity="0.25" stroke="#10B981" stroke-width="1.5" stroke-dasharray="3 2"/>
            <circle cx="21" cy="21" r="10" fill="#141413" stroke="#FFFFFF" stroke-width="2"/>
            <circle cx="21" cy="21" r="4" fill="#10B981"/>
          </svg>
        `;
      }

      const popup = new maplibregl.Popup({ offset: 18, maxWidth: '240px', closeButton: true, closeOnClick: false })
        .setLngLat([parseFloat(activeLoc.lng), parseFloat(activeLoc.lat)])
        .setHTML(`
          <div style="font-family:inherit;min-width:180px;padding:4px;color:#141413;">
            <div style="font-family:monospace;font-size:11px;font-weight:700;border-bottom:1px solid #E5DFD9;padding-bottom:4px;display:flex;align-items:center;gap:6px;">
              <span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:${interactivePicker ? '#CF4500' : '#10B981'};"></span>
              <span>${interactivePicker ? 'SELECTED REGISTRATION POINT' : 'LIVE PATROL GPS FIX'}</span>
            </div>
            <div style="font-family:monospace;color:#696969;font-size:11px;margin-top:6px;">
              Lat: <strong style="color:#141413;">${Number(activeLoc.lat).toFixed(5)}</strong><br/>
              Lng: <strong style="color:#141413;">${Number(activeLoc.lng).toFixed(5)}</strong>
            </div>
            ${isLive ? '<div style="color:#10B981;font-size:10px;font-weight:600;margin-top:4px;">● Real-time Live Position Active</div>' : ''}
            ${interactivePicker ? '<div style="color:#CF4500;font-size:10px;font-weight:600;margin-top:4px;">✓ Location locked (Click anywhere to relocate)</div>' : ''}
          </div>
        `);

      const marker = new maplibregl.Marker({ element: el })
        .setLngLat([parseFloat(activeLoc.lng), parseFloat(activeLoc.lat)])
        .addTo(map);

      el.addEventListener('click', (e) => {
        e.stopPropagation();
        e.preventDefault();
        if (activePopupRef.current) {
          activePopupRef.current.remove();
          activePopupRef.current = null;
        }
        popup.addTo(map);
        activePopupRef.current = popup;
      });

      markersRef.current.push(marker);
    }
  }, [cameras, stations, crimeLocation, searchRadius, selectedLocation, effectiveLiveLoc, selectedCameraId, interactivePicker, isSurveyor, onSelectCamera]);

  // 6. Smooth Focus when selectedCameraId changes
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !selectedCameraId || cameras.length === 0) return;

    const found = cameras.find(c => c.id === selectedCameraId);
    if (found && found.latitude && found.longitude) {
      map.flyTo({
        center: [parseFloat(found.longitude), parseFloat(found.latitude)],
        zoom: 16.5,
        pitch: 55,
        bearing: parseFloat(found.directionAngle) || 0,
        duration: 900,
        essential: true
      });
    }
  }, [selectedCameraId, cameras]);

  // Auto-focus on crimeLocation when an investigation case is clicked/selected
  const lastCrimeLocRef = useRef({ lat: null, lng: null, focusKey: null });
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !crimeLocation?.lat || !crimeLocation?.lng) return;
    const targetLat = parseFloat(crimeLocation.lat);
    const targetLng = parseFloat(crimeLocation.lng);
    if (isNaN(targetLat) || isNaN(targetLng)) return;

    const isNewCoords = lastCrimeLocRef.current.lat !== targetLat || lastCrimeLocRef.current.lng !== targetLng;
    const isKeyTrigger = focusKey !== undefined && focusKey !== null && lastCrimeLocRef.current.focusKey !== focusKey;

    if (isKeyTrigger || isNewCoords) {
      lastCrimeLocRef.current = { lat: targetLat, lng: targetLng, focusKey };
      map.flyTo({
        center: [targetLng, targetLat],
        zoom: 16.2,
        pitch: 55,
        duration: 1000,
        essential: true
      });
    }
  }, [crimeLocation?.lat, crimeLocation?.lng, focusKey]);

  // Auto-focus when effectiveLiveLoc updates
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !effectiveLiveLoc?.lat || !effectiveLiveLoc?.lng) return;
    map.flyTo({
      center: [parseFloat(effectiveLiveLoc.lng), parseFloat(effectiveLiveLoc.lat)],
      zoom: 16.5,
      pitch: 50,
      duration: 1000,
      essential: true
    });
  }, [effectiveLiveLoc]);

  const handleTriggerLiveLocation = () => {
    if (onGetLiveLocation) {
      onGetLiveLocation();
      return;
    }
    if (!navigator.geolocation) {
      alert('Geolocation is not supported by your browser.');
      return;
    }
    setInternalIsLocating(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const lat = Math.round(pos.coords.latitude * 100000) / 100000;
        const lng = Math.round(pos.coords.longitude * 100000) / 100000;
        setInternalLiveLoc({ lat, lng });
        setInternalIsLocating(false);
      },
      (err) => {
        console.warn('Live location error:', err);
        setInternalIsLocating(false);
        alert('Unable to retrieve your live GPS location. Please check browser location permissions.');
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    );
  };

  // Viewport Presets
  const handleResetVidarbhaView = () => {
    const map = mapRef.current;
    if (!map) return;
    map.flyTo({
      center: VIDARBHA_CONFIG.center,
      zoom: VIDARBHA_CONFIG.defaultZoom,
      pitch: VIDARBHA_CONFIG.defaultPitch,
      bearing: VIDARBHA_CONFIG.defaultBearing,
      duration: 1000
    });
  };

  const handleAdjustPitch = (delta) => {
    const map = mapRef.current;
    if (!map) return;
    const nextPitch = Math.min(VIDARBHA_CONFIG.maxPitch, Math.max(VIDARBHA_CONFIG.minPitch, map.getPitch() + delta));
    map.easeTo({ pitch: nextPitch, duration: 300 });
  };

  const handleResetNorth = () => {
    const map = mapRef.current;
    if (!map) return;
    map.easeTo({ bearing: 0, duration: 400 });
  };

  const activeCamsCount = cameras.filter(c => c.cameraStatus === 'ACTIVE').length;

  return (
    <div className="w-full h-full relative isolate overflow-hidden select-none bg-[#0B0F19]">
      {/* MapLibre WebGL Canvas Container */}
      <div 
        ref={mapContainerRef} 
        className={`absolute inset-0 w-full h-full ${interactivePicker ? 'cursor-crosshair' : 'cursor-grab'}`}
      />

      {/* UNIFIED TOP BAR: Single non-overlapping responsive flex container */}
      <div className="absolute top-2.5 inset-x-2.5 sm:top-3 sm:inset-x-3 z-10 pointer-events-none flex items-center justify-between gap-1.5 sm:gap-2">
        {/* Left: Tactical Badge */}
        <div className="pointer-events-auto flex items-center gap-1.5 sm:gap-2 bg-[#141413]/90 backdrop-blur-md px-2.5 sm:px-3.5 py-1 sm:py-1.5 rounded-full text-white border border-white/10 shadow-lg text-[10px] sm:text-[11px] font-semibold shrink-0">
          <span className="w-2 h-2 rounded-full bg-[#10B981] shrink-0 animate-pulse"></span>
          <span className="font-bold tracking-tight">3D RECON</span>
          <span className="text-[9px] font-mono text-[#F37338] bg-[#F37338]/20 px-1.5 py-0.5 rounded-full border border-[#F37338]/30">
            NAGPUR
          </span>
          {realtimeClock && (
            <span className="hidden md:inline-flex items-center gap-1 text-[10px] font-mono text-white/70 border-l border-white/20 pl-2">
              <Clock className="w-2.5 h-2.5 text-[#F37338]" />
              {realtimeClock}
            </span>
          )}
        </div>

        {/* Right: Controls Cluster (Engine Switcher, Style Switcher, Fullscreen) */}
        <div className="pointer-events-auto flex items-center gap-1 sm:gap-1.5 shrink-0 ml-auto">
          {/* 2D / 3D Mode Switcher */}
          {onViewModeChange && !interactivePicker && (
            <div className="flex items-center bg-[#141413]/90 backdrop-blur-md p-0.5 rounded-full border border-white/15 shadow-lg">
              <button
                type="button"
                onClick={() => onViewModeChange('2d')}
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
                onClick={() => onViewModeChange('3d')}
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

          {/* 3D Photorealistic Style Switcher (Compact icons) */}
          <div className="flex items-center bg-[#141413]/90 backdrop-blur-md p-0.5 rounded-full border border-white/15 shadow-xl text-white">
            {Object.values(MAP_STYLES).map((style) => {
              const IconComponent = style.icon;
              const isActive = styleMode === style.id;
              return (
                <button
                  key={style.id}
                  type="button"
                  onClick={() => setStyleMode(style.id)}
                  title={style.label}
                  className={`flex items-center gap-1 px-2 py-1 rounded-full text-[10px] font-semibold transition-all ${
                    isActive 
                      ? 'bg-[#CF4500] text-white shadow-md' 
                      : 'text-white/70 hover:text-white hover:bg-white/10'
                  }`}
                >
                  <IconComponent className="w-3 h-3" />
                  <span className="hidden xl:inline">{style.label.replace('3D ', '')}</span>
                </button>
              );
            })}
          </div>

          {/* Fullscreen Expand/Exit Button */}
          {allowFullscreen && onToggleFullscreen && (
            <button
              type="button"
              onClick={onToggleFullscreen}
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

      {/* BOTTOM LEFT: Quick Actions Toolbar */}
      <div className="absolute bottom-2.5 left-2.5 sm:bottom-3 sm:left-3 z-10 pointer-events-auto flex items-center gap-1 sm:gap-1.5 bg-[#141413]/90 backdrop-blur-md px-2.5 py-1 rounded-full border border-white/15 shadow-xl text-white text-xs max-w-[calc(100%-80px)] overflow-x-auto no-scrollbar">
        <button
          type="button"
          onClick={handleResetVidarbhaView}
          title="Reset View to Nagpur Hub"
          className="flex items-center gap-1 px-2 py-0.5 rounded-full bg-white/10 hover:bg-[#CF4500] hover:text-white transition-all active:scale-95 text-[10px] sm:text-[11px] font-medium shrink-0"
        >
          <RotateCcw className="w-2.5 h-2.5 text-[#F37338]" />
          <span>HQ</span>
        </button>

        <div className="h-3 w-px bg-white/20 shrink-0"></div>

        <button
          type="button"
          onClick={handleTriggerLiveLocation}
          title="Acquire Live GPS Patrol Location"
          className="flex items-center gap-1 px-2 py-0.5 rounded-full bg-white/10 hover:bg-[#10B981] hover:text-white transition-all active:scale-95 text-[10px] sm:text-[11px] font-medium text-white/90 shrink-0"
        >
          <Navigation className={`w-2.5 h-2.5 ${effectiveIsLocating ? 'animate-spin text-[#F37338]' : 'text-[#10B981]'}`} />
          <span>{effectiveIsLocating ? 'GPS...' : 'Live GPS'}</span>
        </button>

        <div className="h-3 w-px bg-white/20 shrink-0"></div>

        <button
          type="button"
          onClick={() => handleAdjustPitch(15)}
          title="Adjust Pitch Tilt"
          className="px-2 py-0.5 rounded-full bg-white/10 hover:bg-white/20 transition-all text-[9px] sm:text-[10px] font-mono font-bold shrink-0"
        >
          Tilt {currentPitch}°
        </button>
      </div>

      {/* BOTTOM RIGHT: Unified Compass & Tactical Zoom Controls (Single non-overlapping vertical flex stack) */}
      <div className="absolute bottom-2.5 right-2.5 sm:bottom-3 sm:right-3 z-10 pointer-events-auto flex flex-col items-center gap-1.5 scale-75 sm:scale-85 origin-bottom-right">
        <MapCompass
          bearing={currentBearing}
          onResetNorth={handleResetNorth}
          title="Surveillance Compass (Click to reset North)"
        />

        {/* Tactical Dark Glass Zoom Controls */}
        <div className="flex flex-col items-center bg-[#141413]/90 backdrop-blur-md rounded-2xl border border-white/15 overflow-hidden shadow-xl text-white">
          <button
            type="button"
            onClick={() => mapRef.current?.zoomIn({ duration: 250 })}
            className="p-2 hover:bg-white/10 active:bg-white/20 transition-all text-white/90 hover:text-white"
            title="Zoom In"
          >
            <Plus className="w-4 h-4" />
          </button>
          <div className="h-px w-5 bg-white/15" />
          <button
            type="button"
            onClick={() => mapRef.current?.zoomOut({ duration: 250 })}
            className="p-2 hover:bg-white/10 active:bg-white/20 transition-all text-white/90 hover:text-white"
            title="Zoom Out"
          >
            <Minus className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
};
