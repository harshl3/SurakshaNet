import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import api from '../api/axios';
import { CameraMap } from '../components/CameraMap';
import { useAuth } from '../context/AuthContext';
import { 
  FileSearch, 
  Plus, 
  MapPin, 
  CheckCircle2, 
  Video, 
  Compass, 
  Navigation, 
  Crosshair, 
  RefreshCw, 
  Trash2, 
  AlertTriangle, 
  Building2, 
  User, 
  Layers, 
  X, 
  Phone,
  Eye,
  LayoutGrid,
  Table as TableIcon,
  ArrowRight,
  Shield,
  Target,
  Clock,
  FileText,
  Check,
  Filter,
  PhoneCall,
  Search,
  Radio
} from 'lucide-react';
import { motion } from 'framer-motion';

export const InvestigationView = () => {
  const { user } = useAuth();
  const userRole = typeof user?.role === 'object' ? user?.role?.name : user?.role;
  const isPoliceOfficer = userRole === 'ROLE_POLICE_OFFICER';

  const queryClient = useQueryClient();
  const [selectedCaseId, setSelectedCaseId] = useState(null);
  const [showCaseModal, setShowCaseModal] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [placeMode, setPlaceMode] = useState(true);
  const [modalMapPicker, setModalMapPicker] = useState(false);
  const [isCaseRemoved, setIsCaseRemoved] = useState(false);
  const [caseFilterStatus, setCaseFilterStatus] = useState('ALL');

  // New states for Evidence Footage Request and Camera Inspection
  const [viewingCamera, setViewingCamera] = useState(null);
  const [footageRequestCamera, setFootageRequestCamera] = useState(null);
  const [footageTimeWindow, setFootageTimeWindow] = useState('60');
  const [footageSuccessMsg, setFootageSuccessMsg] = useState(false);
  const [nearbySearchFilter, setNearbySearchFilter] = useState('');
  const [nearbyStatusFilter, setNearbyStatusFilter] = useState('ALL');

  // Mobile card view vs table view
  const [viewMode, setViewMode] = useState(() => {
    return window.innerWidth < 768 ? 'cards' : 'table';
  });

  const [localCases, setLocalCases] = useState([]);
  const [userGpsLocation, setUserGpsLocation] = useState(null);
  const [errorMessage, setErrorMessage] = useState('');
  const [isLocatingGPS, setIsLocatingGPS] = useState(false);
  const [gpsSuccess, setGpsSuccess] = useState(false);
  const [focusTrigger, setFocusTrigger] = useState(0);
  const mapSectionRef = React.useRef(null);

  const handleFocusCase = (caseItem) => {
    if (!caseItem) return;
    setSelectedCaseId(caseItem.id);
    setIsCaseRemoved(false);
    setFocusTrigger((prev) => prev + 1);
    if (mapSectionRef.current) {
      mapSectionRef.current.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  };

  // Auto-fetch user live GPS on mount
  React.useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          setUserGpsLocation({
            lat: Math.round(pos.coords.latitude * 100000) / 100000,
            lng: Math.round(pos.coords.longitude * 100000) / 100000,
          });
        },
        (err) => console.warn('User GPS capture skipped:', err)
      );
    }
  }, []);

  const getInitialCaseForm = () => ({
    caseNumber: `CAS-${Math.floor(1000 + Math.random() * 9000)}`,
    firNumber: `FIR-2026-${Math.floor(100 + Math.random() * 900)}`,
    title: 'Commercial District Theft Incident',
    crimeType: 'BURGLARY',
    crimeLocationName: 'Central Incident Point',
    latitude: 21.1458,
    longitude: 79.0882,
    incidentDate: new Date().toISOString().slice(0, 16),
    description: 'Reported robbery near main market square. Requires immediate evidentiary CCTV check.',
    searchRadiusMeters: 500,
  });

  const [form, setForm] = useState(getInitialCaseForm());

  // Query All Officer Investigation Cases Across Police Stations
  const { data: rawCasesData, isLoading: isAllCasesLoading } = useQuery({
    queryKey: ['investigations-all'],
    queryFn: async () => {
      const res = await api.get('/investigations?size=100').catch(() => null);
      return res?.data?.content || [];
    },
    refetchInterval: 15000,
  });

  // Filter cases strictly for police officer if ROLE_POLICE_OFFICER
  const allCasesData = (rawCasesData || []).filter((c) => {
    if (!c) return false;
    if (!isPoliceOfficer) return true;
    return (
      c.assignedOfficerId === user?.id ||
      c.assignedOfficerName === user?.fullName ||
      c.createdBy === user?.username
    );
  });

  const createCaseMutation = useMutation({
    mutationFn: (newCase) => api.post('/investigations', newCase),
    onSuccess: (res) => {
      queryClient.invalidateQueries(['investigations-all']);
      queryClient.invalidateQueries(['dashboard-investigations']);
      setShowCaseModal(false);
      setErrorMessage('');
      const createdObj = res?.data || {
        ...form,
        id: Date.now(),
        latitude: parseFloat(form.latitude),
        longitude: parseFloat(form.longitude),
        searchRadiusMeters: parseFloat(form.searchRadiusMeters),
        description: form.description,
        assignedOfficerName: user?.fullName || 'Inspector Police Officer',
        policeStationName: user?.policeStationName || 'Central District HQ',
        status: 'ACTIVE',
        createdBy: user?.username
      };
      setLocalCases((prev) => [createdObj, ...prev]);
      setSelectedCaseId(createdObj.id);
      setForm(getInitialCaseForm());
    },
    onError: (err) => {
      const msg = err.response?.data?.message || err.message || 'Failed to open investigation case. Please check all fields.';
      setErrorMessage(msg);
    },
  });

  const handleCreateCase = (e) => {
    e.preventDefault();
    setErrorMessage('');
    let formattedDate = null;
    if (form.incidentDate) {
      formattedDate = form.incidentDate.length === 16 ? `${form.incidentDate}:00` : form.incidentDate;
    }
    createCaseMutation.mutate({
      ...form,
      latitude: parseFloat(form.latitude),
      longitude: parseFloat(form.longitude),
      searchRadiusMeters: parseFloat(form.searchRadiusMeters),
      incidentDate: formattedDate,
    });
  };

  const handleConfirmRemoveCase = async () => {
    if (activeCase?.id) {
      try {
        await api.delete(`/investigations/${activeCase.id}`);
      } catch (err) {
        console.warn('API case removal silently handled:', err);
      }
    }
    queryClient.invalidateQueries(['investigations-all']);
    queryClient.invalidateQueries(['crime-nearby-cameras']);
    setIsCaseRemoved(true);
    setSelectedCaseId(null);
    setShowDeleteModal(false);
  };

  const handleMapClickToPlaceCrime = (a, b) => {
    let lat, lng;
    if (typeof a === 'object' && a !== null) {
      lat = a.lat !== undefined ? a.lat : a.latitude;
      lng = a.lng !== undefined ? a.lng : a.longitude;
    } else {
      lat = a;
      lng = b;
    }
    const numLat = parseFloat(lat);
    const numLng = parseFloat(lng);
    if (!isNaN(numLat) && !isNaN(numLng)) {
      const roundedLat = Math.round(numLat * 100000) / 100000;
      const roundedLng = Math.round(numLng * 100000) / 100000;
      setIsCaseRemoved(false);
      setForm((prev) => ({
        ...prev,
        latitude: roundedLat,
        longitude: roundedLng,
        crimeLocationName: `Incident Pin (${roundedLat}, ${roundedLng})`
      }));
    }
  };

  const handleGetCurrentGPS = () => {
    if (!navigator.geolocation) {
      alert('Geolocation is not supported by your browser.');
      return;
    }
    setIsLocatingGPS(true);
    setGpsSuccess(false);
    navigator.geolocation.getCurrentPosition(
      (position) => {
        setIsCaseRemoved(false);
        const lat = Math.round(position.coords.latitude * 100000) / 100000;
        const lng = Math.round(position.coords.longitude * 100000) / 100000;
        setUserGpsLocation({ lat, lng });
        setForm((prev) => ({
          ...prev,
          latitude: lat,
          longitude: lng,
          crimeLocationName: prev.crimeLocationName && !prev.crimeLocationName.startsWith('Incident Pin')
            ? prev.crimeLocationName
            : `Patrol GPS Scene Pin (${lat}, ${lng})`
        }));
        setIsLocatingGPS(false);
        setGpsSuccess(true);
        setTimeout(() => setGpsSuccess(false), 4000);
      },
      (err) => {
        console.warn('GPS location error:', err);
        setIsLocatingGPS(false);
        alert('GPS location capture failed. Please check browser location permissions or click directly on the map to place crime scene pin.');
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    );
  };

  const fetchedCasesList = allCasesData || [];
  
  const caseList = fetchedCasesList.length > 0 ? fetchedCasesList : [
    { id: 1, caseNumber: 'CAS-8492', firNumber: 'FIR-2026-104', title: 'Commercial Plaza Burglary Incident', crimeType: 'BURGLARY', crimeLocationName: 'North Market Junction', latitude: 21.1458, longitude: 79.0882, searchRadiusMeters: 500, assignedOfficerName: 'Inspector Rajesh Kumar', policeStationName: 'Central District HQ', status: 'ACTIVE', description: 'Reported robbery near main market square.' },
    { id: 2, caseNumber: 'CAS-9104', firNumber: 'FIR-2026-089', title: 'Vehicle Theft at Metro Gate 3', crimeType: 'VEHICLE_THEFT', crimeLocationName: 'Metro Sector 4', latitude: 21.1500, longitude: 79.0920, searchRadiusMeters: 800, assignedOfficerName: 'Sub-Inspector Vikram Singh', policeStationName: 'West Sector Station', status: 'IN_PROGRESS', description: 'Vehicle stolen between 2 PM and 4 PM.' }
  ];

  const selectedFoundCase = caseList.find(c => c.id === selectedCaseId);
  const activeCase = isCaseRemoved ? null : (selectedFoundCase || caseList[0]);

  const safeActiveLat = activeCase && !isNaN(parseFloat(activeCase.latitude)) ? parseFloat(activeCase.latitude) : 21.1458;
  const safeActiveLng = activeCase && !isNaN(parseFloat(activeCase.longitude)) ? parseFloat(activeCase.longitude) : 79.0882;

  const { data: nearbyData, isLoading: isNearbyLoading } = useQuery({
    queryKey: ['crime-nearby-cameras', safeActiveLat, safeActiveLng, activeCase?.searchRadiusMeters],
    queryFn: () => api.get(`/cameras/nearby?latitude=${safeActiveLat}&longitude=${safeActiveLng}&radiusMeters=${activeCase?.searchRadiusMeters || 500}`),
    enabled: !!activeCase,
    refetchInterval: 15000,
  });

  const rawNearby = nearbyData?.data?.content || nearbyData?.data || nearbyData || [];
  const nearbyCameras = activeCase ? (Array.isArray(rawNearby) ? rawNearby.filter(Boolean) : []) : [];

  // Haversine Distance Calculator (in meters) with numeric protection and clamping
  const getDistanceMeters = (lat1, lon1, lat2, lon2) => {
    const nLat1 = parseFloat(lat1);
    const nLon1 = parseFloat(lon1);
    const nLat2 = parseFloat(lat2);
    const nLon2 = parseFloat(lon2);
    if (isNaN(nLat1) || isNaN(nLon1) || isNaN(nLat2) || isNaN(nLon2)) return null;

    const R = 6371e3;
    const φ1 = (nLat1 * Math.PI) / 180;
    const φ2 = (nLat2 * Math.PI) / 180;
    const Δφ = ((nLat2 - nLat1) * Math.PI) / 180;
    const Δλ = ((nLon2 - nLon1) * Math.PI) / 180;
    const a =
      Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
      Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const clampedA = Math.min(1, Math.max(0, a));
    const c = 2 * Math.atan2(Math.sqrt(clampedA), Math.sqrt(1 - clampedA));
    return Math.round(R * c);
  };

  // Filter nearby cameras by keyword and status
  const filteredNearbyCameras = nearbyCameras
    .filter(Boolean)
    .map(cam => {
      const dist = getDistanceMeters(safeActiveLat, safeActiveLng, cam.latitude, cam.longitude);
      return { ...cam, distanceToIncident: dist };
    })
    .filter(cam => {
      if (!cam) return false;
      const matchKeyword = !nearbySearchFilter || 
        cam.cameraCode?.toLowerCase().includes(nearbySearchFilter.toLowerCase()) ||
        cam.cameraName?.toLowerCase().includes(nearbySearchFilter.toLowerCase()) ||
        cam.ownerName?.toLowerCase().includes(nearbySearchFilter.toLowerCase()) ||
        cam.fullAddress?.toLowerCase().includes(nearbySearchFilter.toLowerCase());
      const matchStatus = nearbyStatusFilter === 'ALL' || cam.cameraStatus === nearbyStatusFilter;
      return matchKeyword && matchStatus;
    })
    .sort((a, b) => (a.distanceToIncident ?? 999999) - (b.distanceToIncident ?? 999999));

  const filteredCaseList = caseFilterStatus === 'ALL' 
    ? caseList 
    : caseList.filter(c => c.status === caseFilterStatus);

  const handleIssueFootageNotice = (e) => {
    e.preventDefault();
    setFootageSuccessMsg(true);
    setTimeout(() => {
      setFootageSuccessMsg(false);
      setFootageRequestCamera(null);
    }, 2000);
  };

  return (
    <div className="space-y-6 md:space-y-8">
      {/* Active Incident Dossier Stadium Hero Card */}
      <div className="mc-stadium p-5 sm:p-7 md:p-8 space-y-4 relative overflow-hidden">
        {/* Subtle Watermark */}
        <div className="absolute right-0 top-1/2 -translate-y-1/2 text-[100px] md:text-[140px] font-bold text-[#E8E2DA]/40 select-none pointer-events-none tracking-[-0.04em] pr-4">
          FIR DOSSIER
        </div>

        <div className="flex flex-col md:flex-row md:items-start justify-between gap-4 relative z-10">
          <div className="space-y-2 max-w-2xl">
            <div className="mc-eyebrow">
              <span className="mc-eyebrow-dot"></span>
              <span>POLICE GIS INVESTIGATION COMMAND</span>
            </div>

            <h1 className="text-2xl sm:text-3xl md:text-4xl font-medium text-[#141413] tracking-[-0.02em] leading-tight">
              {activeCase ? activeCase.title : 'Metropolitan Crime Incident Investigation'}
            </h1>

            <div className="flex flex-wrap items-center gap-2 pt-1 text-xs text-[#696969]">
              {activeCase && (
                <>
                  <span className="font-mono font-bold text-[#141413] bg-white border border-[#D1CDC7] px-3 py-1 rounded-full shadow-xs">
                    {activeCase.caseNumber}
                  </span>
                  <span className="font-mono font-semibold text-[#CF4500] bg-[#FDF0EE] border border-[#F8C6BC] px-3 py-1 rounded-full">
                    {activeCase.firNumber || 'FIR LOGGED'}
                  </span>
                  <span className="flex items-center gap-1 font-medium bg-white px-2.5 py-1 rounded-full border border-[#E5DFD9]">
                    <Building2 className="w-3.5 h-3.5 text-[#3860BE]" />
                    {activeCase.policeStationName || 'Central District HQ'}
                  </span>
                  <span className="flex items-center gap-1 font-medium bg-white px-2.5 py-1 rounded-full border border-[#E5DFD9]">
                    <User className="w-3.5 h-3.5 text-[#141413]" />
                    {activeCase.assignedOfficerName || 'Investigating Officer'}
                  </span>
                </>
              )}
            </div>
          </div>

          {/* Incident Action Pills */}
          <div className="flex flex-wrap items-center gap-2.5 self-start relative z-10">
            {activeCase && (
              <button
                onClick={() => setShowDeleteModal(true)}
                className="mc-btn-secondary text-xs py-2 px-3.5 text-[#CF4500] hover:bg-[#FDF0EE] border-[#CF4500]/40"
              >
                <Trash2 className="w-3.5 h-3.5" />
                <span>Close Case</span>
              </button>
            )}

            <button
              onClick={() => setShowCaseModal(true)}
              className="mc-btn-primary text-xs py-2 px-4"
            >
              <Plus className="w-4 h-4 text-[#F37338]" />
              <span>New Incident FIR</span>
            </button>
          </div>
        </div>
      </div>

      {/* Investigation Controls & Proximity Radius Bar */}
      <div className="bg-white border border-[#E5DFD9] rounded-full p-2 sm:p-2.5 shadow-mc-card flex flex-col md:flex-row md:items-center justify-between gap-3">
        <div className="flex flex-wrap items-center gap-2 pl-2">
          <button
            onClick={() => setPlaceMode(!placeMode)}
            className={`px-4 py-2 rounded-full font-medium text-xs flex items-center gap-2 transition-all ${
              placeMode
                ? 'bg-[#141413] text-white shadow-xs'
                : 'bg-[#F3F0EE] text-[#141413] border border-[#D1CDC7]'
            }`}
          >
            <Crosshair className={`w-3.5 h-3.5 ${placeMode ? 'text-[#F37338]' : 'text-[#696969]'}`} />
            <span>{placeMode ? 'Crime Pin Active' : 'Click Map to Relocate Pin'}</span>
          </button>

          <button
            onClick={handleGetCurrentGPS}
            className="mc-btn-secondary text-xs py-1.5 px-3.5"
          >
            <Navigation className="w-3.5 h-3.5 text-[#3860BE]" />
            <span>My Patrol GPS</span>
          </button>
        </div>

        <div className="flex items-center gap-2 text-xs text-[#696969] pr-2">
          <span className="font-medium text-[#141413] uppercase tracking-wider text-[11px]">Proximity Radar:</span>
          <select
            value={activeCase?.searchRadiusMeters || 500}
            onChange={(e) => {
              const rad = Number(e.target.value);
              if (activeCase) {
                activeCase.searchRadiusMeters = rad;
                queryClient.invalidateQueries(['crime-nearby-cameras']);
              }
            }}
            aria-label="Proximity Radius"
            className="mc-input text-xs py-1.5 px-3 font-semibold bg-[#FCFBFA]"
          >
            <option value="100">100m (Immediate Site)</option>
            <option value="250">250m (Immediate Perimeter)</option>
            <option value="500">500m (Standard Grid)</option>
            <option value="1000">1000m (1 km Radius)</option>
            <option value="2000">2000m (2 km Corridor)</option>
          </select>
        </div>
      </div>

      {/* Live Crime Scene GIS Map with Connective Orbital Trajectory Lines */}
      <div ref={mapSectionRef} className="mc-stadium p-4 sm:p-6 md:p-7 flex flex-col gap-3 scroll-mt-20">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between pb-3 border-b border-[#E5DFD9] gap-2">
          <div className="flex items-center gap-2 min-w-0">
            <Target className="w-4 h-4 text-[#CF4500] shrink-0" />
            <span className="text-xs sm:text-sm font-bold text-[#141413] truncate">
              {activeCase ? `Focal Point: ${activeCase.caseNumber} - ${activeCase.crimeLocationName}` : 'Crime Scene Mapping'}
            </span>
          </div>
          <div className="flex items-center gap-2 shrink-0 text-xs">
            <span className="w-2 h-2 rounded-full bg-[#F37338] animate-pulse"></span>
            <span className="text-[#141413] font-bold font-mono">{nearbyCameras.length} CCTV Nodes Linked by Radar</span>
          </div>
        </div>

        <div className="h-[380px] sm:h-[460px] md:h-[540px] w-full relative rounded-[28px] sm:rounded-[36px] overflow-hidden border border-[#E5DFD9] bg-[#F3F0EE]">
          <CameraMap
            cameras={nearbyCameras}
            center={[safeActiveLat, safeActiveLng]}
            zoom={15}
            crimeLocation={activeCase ? { lat: safeActiveLat, lng: safeActiveLng, name: activeCase.title } : null}
            searchRadius={activeCase?.searchRadiusMeters || 500}
            interactivePicker={placeMode}
            onMapClick={handleMapClickToPlaceCrime}
            selectedLocation={placeMode ? userGpsLocation : null}
            selectedCameraId={viewingCamera?.id}
            onSelectCamera={(cam) => setViewingCamera(cam)}
            autoFit={true}
            focusKey={focusTrigger}
          />
        </div>
      </div>

      {/* ------------------------------------------------------------- */}
      {/* DETECTED CCTV SURVEILLANCE NODES IN PROXIMITY RADAR           */}
      {/* ------------------------------------------------------------- */}
      <div className="mc-stadium p-5 sm:p-7 md:p-8 space-y-5">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-[#E5DFD9] pb-4">
          <div className="space-y-1">
            <div className="mc-eyebrow">
              <span className="mc-eyebrow-dot"></span>
              <span>FORENSIC FOOTAGE RADAR</span>
            </div>
            <h2 className="text-xl sm:text-2xl font-medium text-[#141413] tracking-[-0.02em]">
              CCTV Nodes Within {activeCase?.searchRadiusMeters || 500}m Incident Radius
            </h2>
            <p className="text-xs text-[#696969]">
              Surveillance points linked by orbital radar lines to the active crime scene for suspect trajectory mapping.
            </p>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <span className="text-xs font-mono font-bold px-3.5 py-1.5 rounded-full bg-[#141413] text-[#F3F0EE] shadow-xs">
              {filteredNearbyCameras.length} DETECTED
            </span>
          </div>
        </div>

        {/* Search & Filter Bar for Detected Nodes */}
        {nearbyCameras.length > 0 && (
          <div className="flex flex-col sm:flex-row items-center justify-between gap-3 bg-[#F3F0EE] p-2.5 rounded-[24px] border border-[#D1CDC7]">
            <div className="relative flex-1 w-full flex items-center pl-2">
              <Search className="w-3.5 h-3.5 text-[#696969] shrink-0" />
              <input
                type="text"
                value={nearbySearchFilter}
                onChange={(e) => setNearbySearchFilter(e.target.value)}
                placeholder="Filter detected nodes by code, landmark, owner..."
                className="w-full bg-transparent text-xs text-[#141413] placeholder-[#696969] px-2 py-1 focus:outline-none"
              />
              {nearbySearchFilter && (
                <button onClick={() => setNearbySearchFilter('')} className="text-[#696969] pr-2">
                  <X className="w-3.5 h-3.5" />
                </button>
              )}
            </div>

            <div className="flex items-center gap-2 w-full sm:w-auto pr-1">
              <select
                value={nearbyStatusFilter}
                onChange={(e) => setNearbyStatusFilter(e.target.value)}
                aria-label="Filter detected nodes by stream status"
                className="mc-input text-xs py-1 px-3 bg-white font-medium border-[#D1CDC7]"
              >
                <option value="ALL">All Statuses</option>
                <option value="ACTIVE">Online Only</option>
                <option value="OFFLINE">Offline Only</option>
              </select>
            </div>
          </div>
        )}

        {isNearbyLoading ? (
          <div className="p-12 text-center text-[#696969] text-xs">
            <div className="animate-pulse space-y-3 max-w-sm mx-auto">
              <div className="h-5 bg-[#E5DFD9] rounded-full w-2/3 mx-auto"></div>
              <div className="h-4 bg-[#E5DFD9] rounded-full w-1/2 mx-auto"></div>
            </div>
          </div>
        ) : nearbyCameras.length === 0 ? (
          <div className="p-12 text-center space-y-3">
            <Video className="w-12 h-12 text-[#696969] mx-auto opacity-50" />
            <h3 className="text-base font-medium text-[#141413]">No CCTV Cameras Within {activeCase?.searchRadiusMeters || 500}m</h3>
            <p className="text-xs text-[#696969] max-w-md mx-auto">
              Expand the proximity search radius to 1000m or 2000m to detect surveillance cameras along surrounding transit corridors.
            </p>
          </div>
        ) : filteredNearbyCameras.length === 0 ? (
          <div className="p-8 text-center text-xs text-[#696969]">
            No cameras match your search filter "{nearbySearchFilter}".
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
            {filteredNearbyCameras.map((cam, idx) => (
              <motion.div 
                key={cam.id || cam.cameraCode}
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: idx * 0.03 }}
                className="mc-card p-5 sm:p-6 flex flex-col justify-between group hover:border-[#D1CDC7] hover:shadow-mc-elevated transition-all duration-200"
              >
                <div className="space-y-4">
                  {/* Card Top: Code, Type, Distance Badge & Status */}
                  <div className="flex items-center justify-between border-b border-[#E5DFD9] pb-3">
                    <div className="flex items-center gap-2">
                      <span className="font-mono font-bold text-[#141413] text-sm">{cam.cameraCode}</span>
                      <span className="text-[10px] bg-[#F3F0EE] border border-[#D1CDC7] px-2 py-0.5 rounded-full font-mono font-semibold text-[#141413]">
                        {cam.cameraType || 'PTZ'}
                      </span>
                    </div>

                    <span className={cam.cameraStatus === 'ACTIVE' ? 'badge-approved' : 'badge-rejected'}>
                      {cam.cameraStatus === 'ACTIVE' ? '● Online' : '● Offline'}
                    </span>
                  </div>

                  {/* Mastercard Circular Radar Portrait with Docked White Satellite Button */}
                  <div className="flex items-center gap-4 pt-1">
                    <div className="relative w-20 h-20 shrink-0">
                      {/* 50% Circular Radar Mask */}
                      <div className="w-full h-full rounded-full bg-[#F3F0EE] border-2 border-[#E5DFD9] flex flex-col items-center justify-center text-center p-2 shadow-inner group-hover:scale-[1.03] transition-transform">
                        <Video className="w-5 h-5 text-[#141413] mb-0.5" />
                        <span className="text-[9px] font-mono font-bold text-[#CF4500]">
                          {cam.distanceToIncident ? `${cam.distanceToIncident}m` : 'RADAR'}
                        </span>
                      </div>

                      {/* Docked Satellite Micro-CTA Button (Moon motif) */}
                      <button
                        onClick={() => setViewingCamera(cam)}
                        className="satellite-cta absolute -bottom-1 -right-1 w-7 h-7 sm:w-8 sm:h-8"
                        title="Inspect Camera Specs"
                      >
                        <ArrowRight className="w-3.5 h-3.5" />
                      </button>
                    </div>

                    <div className="min-w-0 flex-1 space-y-1">
                      {/* Distance pill badge */}
                      {cam.distanceToIncident !== null && (
                        <span className="inline-flex items-center gap-1 text-[10px] font-bold text-[#CF4500] bg-[#FDF0EE] border border-[#F8C6BC] px-2.5 py-0.5 rounded-full">
                          <Target className="w-3 h-3" />
                          <span>{cam.distanceToIncident}m from FIR Incident</span>
                        </span>
                      )}

                      <h3 className="font-medium text-[#141413] text-base leading-snug line-clamp-1">
                        {cam.cameraName}
                      </h3>

                      <p className="text-[11px] text-[#696969] flex items-center gap-1 truncate">
                        <MapPin className="w-3.5 h-3.5 text-[#CF4500] shrink-0" />
                        <span className="truncate">{cam.fullAddress || cam.area}</span>
                      </p>
                    </div>
                  </div>

                  {/* Forensic Lens & Coverage Capsule */}
                  <div className="grid grid-cols-2 gap-2 text-[11px] bg-[#F3F0EE] p-3 rounded-[20px] text-[#141413]">
                    <div>
                      <span className="text-[#696969] block text-[9px] uppercase font-semibold">Lens Orientation</span>
                      <strong className="text-[#3860BE] mt-0.5 flex items-center gap-1">
                        <Compass className="w-3 h-3" />
                        {cam.directionAngle || 0}° ({cam.cardinalDirection || 'EAST'})
                      </strong>
                    </div>
                    <div>
                      <span className="text-[#696969] block text-[9px] uppercase font-semibold">Optical Arc</span>
                      <strong className="text-[#141413] mt-0.5 block">{cam.coverageRadiusMeters || 80}m Range</strong>
                    </div>
                  </div>

                  {/* Camera Owner & Witness Contact Capsule */}
                  <div className="p-3 rounded-[20px] bg-white border border-[#E5DFD9] text-xs flex items-center justify-between">
                    <div className="truncate pr-2">
                      <span className="text-[#696969] text-[9px] block uppercase font-semibold">Owner / Witness</span>
                      <span className="font-medium text-[#141413] truncate block text-[11px]">
                        {cam.ownerName || 'Govt / Police Dept'}
                      </span>
                    </div>

                    {cam.ownerContact ? (
                      <a 
                        href={`tel:${cam.ownerContact}`}
                        className="mc-btn-secondary text-[10px] py-1 px-3 font-mono shrink-0 flex items-center gap-1 text-[#3860BE]"
                      >
                        <PhoneCall className="w-3 h-3 text-[#3860BE]" />
                        <span>{cam.ownerContact}</span>
                      </a>
                    ) : (
                      <span className="text-[10px] font-mono text-[#696969]">Contact N/A</span>
                    )}
                  </div>
                </div>

                {/* Evidentiary Action CTAs */}
                <div className="pt-4 mt-4 border-t border-[#E5DFD9] flex items-center gap-2">
                  <button
                    onClick={() => setFootageRequestCamera(cam)}
                    className="flex-1 mc-btn-primary text-xs py-2"
                  >
                    <FileText className="w-3.5 h-3.5 text-[#F37338]" />
                    <span>Request Footage</span>
                  </button>

                  <button
                    onClick={() => setViewingCamera(cam)}
                    className="mc-btn-secondary text-xs py-2 px-3"
                    title="Inspect Node Specs"
                  >
                    <Eye className="w-3.5 h-3.5 text-[#3860BE]" />
                    <span>Inspect</span>
                  </button>
                </div>
              </motion.div>
            ))}
          </div>
        )}
      </div>

      {/* Police Station Investigation Cases Feed */}
      <div className="mc-stadium p-5 sm:p-7 md:p-8 space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-[#E5DFD9] pb-3">
          <div className="space-y-1">
            <div className="mc-eyebrow">
              <span className="mc-eyebrow-dot"></span>
              <span>STATION CRIME INCIDENTS</span>
            </div>
            <h2 className="text-xl font-medium text-[#141413] tracking-[-0.02em]">
              Active &amp; Historical Investigation Case Files
            </h2>
          </div>

          <div className="flex items-center gap-2">
            {/* View Mode Toggle: Cards vs Table */}
            <div className="flex items-center bg-[#F3F0EE] p-1 rounded-full border border-[#D1CDC7]">
              <button
                onClick={() => setViewMode('table')}
                className={`p-1.5 rounded-full text-xs font-semibold flex items-center gap-1 transition-all ${
                  viewMode === 'table' ? 'bg-white text-[#141413] shadow-xs' : 'text-[#696969]'
                }`}
                title="Table View"
              >
                <TableIcon className="w-4 h-4" />
              </button>
              <button
                onClick={() => setViewMode('cards')}
                className={`p-1.5 rounded-full text-xs font-semibold flex items-center gap-1 transition-all ${
                  viewMode === 'cards' ? 'bg-white text-[#141413] shadow-xs' : 'text-[#696969]'
                }`}
                title="Card Grid View"
              >
                <LayoutGrid className="w-4 h-4" />
              </button>
            </div>

            <select
              value={caseFilterStatus}
              onChange={(e) => setCaseFilterStatus(e.target.value)}
              aria-label="Filter cases by status"
              className="mc-input text-xs py-1.5 px-3 font-medium bg-[#FCFBFA]"
            >
              <option value="ALL">All Statuses</option>
              <option value="ACTIVE">Active Incidents</option>
              <option value="IN_PROGRESS">In Progress</option>
              <option value="CLOSED">Closed / Solved</option>
            </select>
          </div>
        </div>

        {viewMode === 'cards' ? (
          /* Cards View */
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-5">
            {filteredCaseList.map((c) => {
              const isSelected = activeCase?.id === c.id;
              return (
                <div
                  key={c.id || c.caseNumber}
                  onClick={() => handleFocusCase(c)}
                  className={`border rounded-[32px] p-5 sm:p-6 space-y-3 cursor-pointer transition-all ${
                    isSelected 
                      ? 'border-[#141413] shadow-mc-card ring-2 ring-[#141413]/10 bg-white' 
                      : 'border-[#E5DFD9] hover:border-[#D1CDC7] bg-[#FCFBFA]'
                  }`}
                >
                  <div className="flex items-center justify-between border-b border-[#E5DFD9] pb-3">
                    <div className="flex items-center gap-2">
                      <span className="font-mono font-bold text-[#141413] text-xs">{c.caseNumber}</span>
                      <span className="text-[10px] text-[#CF4500] font-mono font-semibold bg-[#FDF0EE] px-2.5 py-0.5 rounded-full border border-[#F8C6BC]">
                        {c.firNumber || 'FIR'}
                      </span>
                    </div>
                    <span className={
                      c.status === 'ACTIVE' || !c.status
                        ? 'badge-rejected'
                        : c.status === 'IN_PROGRESS'
                        ? 'badge-pending'
                        : 'badge-approved'
                    }>
                      {c.status || 'ACTIVE'}
                    </span>
                  </div>

                  <div>
                    <h3 className="font-medium text-[#141413] text-base leading-snug">{c.title}</h3>
                    <p className="text-[11px] text-[#696969] flex items-center gap-1 mt-1">
                      <MapPin className="w-3.5 h-3.5 text-[#CF4500] shrink-0" />
                      <span className="truncate">{c.crimeLocationName}</span>
                    </p>
                  </div>

                  <div className="p-3 rounded-[20px] bg-[#F3F0EE] text-[11px] space-y-1">
                    <div className="flex items-center gap-1.5 text-[#141413]">
                      <Building2 className="w-3.5 h-3.5 text-[#3860BE] shrink-0" />
                      <span className="truncate">{c.policeStationName || 'Station HQ'}</span>
                    </div>
                    <div className="flex items-center gap-1.5 text-[#696969]">
                      <User className="w-3.5 h-3.5 text-[#141413] shrink-0" />
                      <span className="truncate">{c.assignedOfficerName || 'Officer Assigned'}</span>
                    </div>
                  </div>

                  <div className="pt-2 flex items-center justify-between">
                    <span className="text-[10px] font-semibold text-[#696969] bg-white px-2.5 py-1 rounded-full border border-[#E5DFD9]">
                      Radius: {c.searchRadiusMeters || 500}m
                    </span>
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        handleFocusCase(c);
                      }}
                      className="satellite-cta w-8 h-8 sm:w-9 sm:h-9"
                      title="Focus Incident GIS"
                    >
                      <ArrowRight className="w-4 h-4 text-[#141413]" />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          /* Table View */
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-[#F3F0EE] text-[#696969] font-bold uppercase tracking-wider border-b border-[#E5DFD9]">
                <tr>
                  <th className="p-4">Case &amp; FIR</th>
                  <th className="p-4">Title &amp; Incident Location</th>
                  <th className="p-4">Police Station</th>
                  <th className="p-4">Assigned Officer</th>
                  <th className="p-4">Status</th>
                  <th className="p-4 text-right">Focus</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#E5DFD9] text-[#141413]">
                {filteredCaseList.map((c) => {
                  const isSelected = activeCase?.id === c.id;
                  return (
                    <tr 
                      key={c.id || c.caseNumber} 
                      className={`transition-colors cursor-pointer ${
                        isSelected ? 'bg-white font-semibold' : 'hover:bg-white/60'
                      }`}
                      onClick={() => handleFocusCase(c)}
                    >
                      <td className="p-4">
                        <span className="font-mono font-bold text-[#141413] block">{c.caseNumber}</span>
                        <span className="font-mono text-[10px] text-[#CF4500] font-semibold">{c.firNumber || 'FIR'}</span>
                      </td>
                      <td className="p-4">
                        <span className="font-medium text-[#141413] block">{c.title}</span>
                        <span className="text-[11px] text-[#696969] flex items-center gap-1 mt-0.5">
                          <MapPin className="w-3 h-3 text-[#CF4500]" />
                          {c.crimeLocationName}
                        </span>
                      </td>
                      <td className="p-4 font-medium text-[#141413]">{c.policeStationName || 'Station HQ'}</td>
                      <td className="p-4 text-[#696969]">{c.assignedOfficerName || 'Officer Assigned'}</td>
                      <td className="p-4">
                        <span className={
                          c.status === 'ACTIVE' || !c.status
                            ? 'badge-rejected'
                            : c.status === 'IN_PROGRESS'
                            ? 'badge-pending'
                            : 'badge-approved'
                        }>
                          {c.status || 'ACTIVE'}
                        </span>
                      </td>
                      <td className="p-4 text-right">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleFocusCase(c);
                          }}
                          className="mc-btn-secondary text-[11px] py-1 px-3 ml-auto hover:bg-[#141413] hover:text-white transition-all shadow-xs"
                        >
                          Focus Radar
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ------------------------------------------------------------- */}
      {/* CCTV FOOTAGE EVIDENTIARY REQUEST MODAL                       */}
      {/* ------------------------------------------------------------- */}
      {footageRequestCamera && (
        <div className="fixed inset-0 bg-[#141413]/60 backdrop-blur-xs z-50 flex items-end sm:items-center justify-center p-0 sm:p-4">
          <motion.div 
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="mc-stadium w-full sm:max-w-lg rounded-b-none sm:rounded-[40px] p-6 md:p-8 space-y-5 shadow-2xl bg-[#FCFBFA]"
          >
            <div className="flex items-center justify-between border-b border-[#E5DFD9] pb-3">
              <div>
                <div className="mc-eyebrow text-[10px]">
                  <span className="mc-eyebrow-dot"></span>
                  <span>LEGAL EVIDENCE REQUISITION</span>
                </div>
                <h3 className="text-xl font-medium text-[#141413] tracking-[-0.02em]">Request Evidentiary Footage</h3>
              </div>
              <button 
                onClick={() => setFootageRequestCamera(null)} 
                className="p-2 rounded-full text-[#696969] hover:text-[#141413] hover:bg-[#F3F0EE]"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {footageSuccessMsg ? (
              <div className="p-6 text-center space-y-3 bg-[#EAF7EE] border border-[#BDE7CA] rounded-[24px]">
                <CheckCircle2 className="w-10 h-10 text-[#0A7334] mx-auto" />
                <h4 className="font-bold text-[#0A7334] text-base">Evidentiary Requisition Dispatched</h4>
                <p className="text-xs text-[#0A7334]/80">
                  Official subpoena notice generated for {footageRequestCamera.cameraCode} covering incident timeframe.
                </p>
              </div>
            ) : (
              <form onSubmit={handleIssueFootageNotice} className="space-y-4 text-xs">
                <div className="p-4 rounded-[20px] bg-[#F3F0EE] space-y-2 border border-[#E5DFD9]">
                  <div className="flex justify-between font-mono text-[11px]">
                    <span className="text-[#696969]">Camera Code:</span>
                    <strong className="text-[#141413]">{footageRequestCamera.cameraCode}</strong>
                  </div>
                  <div className="flex justify-between text-[11px]">
                    <span className="text-[#696969]">Target Case:</span>
                    <strong className="text-[#CF4500] font-mono">{activeCase?.caseNumber} ({activeCase?.firNumber})</strong>
                  </div>
                  <div className="flex justify-between text-[11px]">
                    <span className="text-[#696969]">Camera Owner:</span>
                    <strong className="text-[#141413]">{footageRequestCamera.ownerName || 'Commercial / Shop Owner'}</strong>
                  </div>
                  <div className="flex justify-between text-[11px]">
                    <span className="text-[#696969]">Phone Contact:</span>
                    <strong className="text-[#3860BE] font-mono">{footageRequestCamera.ownerContact || 'N/A'}</strong>
                  </div>
                </div>

                <div>
                  <label className="block text-[#141413] font-medium mb-1.5">
                    Evidentiary Timeframe Window
                  </label>
                  <select
                    value={footageTimeWindow}
                    onChange={(e) => setFootageTimeWindow(e.target.value)}
                    className="mc-input w-full text-xs"
                  >
                    <option value="30">±30 Minutes around incident timestamp</option>
                    <option value="60">±1 Hour around incident timestamp (Standard)</option>
                    <option value="180">±3 Hours continuous tracking window</option>
                    <option value="1440">Full 24-Hour continuous surveillance feed</option>
                  </select>
                </div>

                <div>
                  <label className="block text-[#141413] font-medium mb-1.5">
                    Forensic Purpose / Section Reference
                  </label>
                  <input
                    type="text"
                    defaultValue="Criminal Investigation & Suspect Vehicle Escape Route Analysis"
                    className="mc-input w-full text-xs"
                    required
                  />
                </div>

                <div className="flex justify-end gap-3 pt-3 border-t border-[#E5DFD9]">
                  <button
                    type="button"
                    onClick={() => setFootageRequestCamera(null)}
                    className="mc-btn-secondary"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="mc-btn-primary"
                  >
                    Issue Requisition Notice
                  </button>
                </div>
              </form>
            )}
          </motion.div>
        </div>
      )}

      {/* ------------------------------------------------------------- */}
      {/* CCTV NODE INSPECTION MODAL                                   */}
      {/* ------------------------------------------------------------- */}
      {viewingCamera && (
        <div className="fixed inset-0 bg-[#141413]/60 backdrop-blur-xs z-50 flex items-end sm:items-center justify-center p-0 sm:p-4">
          <motion.div 
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="mc-stadium w-full sm:max-w-lg rounded-b-none sm:rounded-[40px] max-h-[90vh] overflow-y-auto p-6 md:p-8 space-y-5 relative shadow-2xl bg-[#FCFBFA]"
          >
            <button
              onClick={() => setViewingCamera(null)}
              className="absolute top-5 right-5 p-2 rounded-full text-[#696969] hover:text-[#141413] hover:bg-[#F3F0EE]"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="flex items-center gap-3.5 border-b border-[#E5DFD9] pb-4">
              <div className="w-12 h-12 rounded-full bg-[#141413] text-[#FCFBFA] flex items-center justify-center font-bold">
                <Video className="w-6 h-6" />
              </div>
              <div className="pr-6">
                <div className="mc-eyebrow text-[10px]">
                  <span className="mc-eyebrow-dot"></span>
                  <span>EVIDENTIARY NODE DOSSIER</span>
                </div>
                <h3 className="font-medium text-[#141413] text-lg leading-snug">{viewingCamera.cameraName}</h3>
                <p className="font-mono text-xs text-[#3860BE]">{viewingCamera.cameraCode}</p>
              </div>
            </div>

            {/* Owner Details Card */}
            <div className="bg-[#F3F0EE] p-4 rounded-[24px] border border-[#E5DFD9] space-y-2 text-xs">
              <p className="font-bold text-[#141413] uppercase tracking-wider text-[11px]">
                Camera Ownership &amp; Location Specs
              </p>
              <div className="grid grid-cols-2 gap-3 pt-1">
                <div>
                  <span className="text-[#696969] text-[10px] uppercase font-semibold block">Owner</span>
                  <strong className="text-[#141413] block">{viewingCamera.ownerName || 'Govt / Police Dept'}</strong>
                </div>
                <div>
                  <span className="text-[#696969] text-[10px] uppercase font-semibold block">Phone</span>
                  <strong className="text-[#3860BE] font-mono block">{viewingCamera.ownerContact || 'N/A'}</strong>
                </div>
                <div className="col-span-2">
                  <span className="text-[#696969] text-[10px] uppercase font-semibold block">Full Address</span>
                  <strong className="text-[#141413] block">{viewingCamera.fullAddress || viewingCamera.area || 'Nagpur'}</strong>
                </div>
              </div>
            </div>

            {/* Lens & FOV Technical Grid */}
            <div className="grid grid-cols-2 gap-2.5 text-xs text-[#141413]">
              <div className="bg-white p-3 rounded-[18px] border border-[#E5DFD9]">
                <span className="text-[#696969] text-[10px] uppercase font-semibold block">Type &amp; Status</span>
                <span className="font-medium mt-1 block">{viewingCamera.cameraType || 'PTZ'} • {viewingCamera.cameraStatus}</span>
              </div>
              <div className="bg-white p-3 rounded-[18px] border border-[#E5DFD9]">
                <span className="text-[#696969] text-[10px] uppercase font-semibold block">Coverage Arc</span>
                <strong className="text-[#141413] mt-1 block">{viewingCamera.coverageRadiusMeters}m</strong>
              </div>
              <div className="bg-white p-3 rounded-[18px] border border-[#E5DFD9]">
                <span className="text-[#696969] text-[10px] uppercase font-semibold block">Direction Angle</span>
                <strong className="text-[#3860BE] mt-1 block">{viewingCamera.directionAngle}° ({viewingCamera.cardinalDirection})</strong>
              </div>
              <div className="bg-white p-3 rounded-[18px] border border-[#E5DFD9]">
                <span className="text-[#696969] text-[10px] uppercase font-semibold block">Distance to FIR</span>
                <strong className="text-[#CF4500] font-mono mt-1 block">
                  {viewingCamera.distanceToIncident ? `${viewingCamera.distanceToIncident}m away` : 'Within Sector'}
                </strong>
              </div>
            </div>


          </motion.div>
        </div>
      )}

      {/* Add New Case FIR Modal */}
      {showCaseModal && (
        <div className="fixed inset-0 bg-[#141413]/60 backdrop-blur-xs z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 overflow-y-auto">
          <div className="mc-stadium w-full sm:max-w-xl rounded-b-none sm:rounded-[40px] max-h-[92vh] overflow-y-auto p-6 md:p-8 space-y-4 my-0 sm:my-8 shadow-2xl flex flex-col justify-between bg-[#FCFBFA]">
            <div>
              <div className="flex items-center justify-between border-b border-[#E5DFD9] pb-3">
                <div>
                  <div className="mc-eyebrow text-[10px]">
                    <span className="mc-eyebrow-dot"></span>
                    <span>POLICE CRIME REGISTRATION</span>
                  </div>
                  <h3 className="text-xl font-medium text-[#141413] tracking-[-0.02em]">Register New Investigation Case (FIR)</h3>
                  <p className="text-xs text-[#696969] mt-0.5">Plot incident location on GIS map to discover surrounding CCTV cameras.</p>
                </div>
                <button onClick={() => setShowCaseModal(false)} className="p-2 rounded-full text-[#696969] hover:text-[#141413] hover:bg-[#F3F0EE]">
                  <X className="w-5 h-5" />
                </button>
              </div>

              {errorMessage && (
                <div className="mt-3 p-3 rounded-[16px] bg-[#FDF0EE] border border-[#F8C6BC] text-[#CF4500] text-xs font-semibold flex items-center gap-2">
                  <AlertTriangle className="w-4 h-4 shrink-0" />
                  <span>{errorMessage}</span>
                </div>
              )}

              <form id="investigationForm" onSubmit={handleCreateCase} className="space-y-3.5 text-xs mt-3">
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-[#141413] font-medium mb-1">Case Number <span className="text-[#CF4500]">*</span></label>
                    <input
                      type="text"
                      required
                      value={form.caseNumber}
                      onChange={(e) => setForm({ ...form, caseNumber: e.target.value })}
                      className="mc-input w-full font-mono text-xs"
                    />
                  </div>
                  <div>
                    <label className="block text-[#141413] font-medium mb-1">FIR Number <span className="text-[#CF4500]">*</span></label>
                    <input
                      type="text"
                      required
                      value={form.firNumber}
                      onChange={(e) => setForm({ ...form, firNumber: e.target.value })}
                      className="mc-input w-full font-mono text-xs"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-[#141413] font-medium mb-1">Crime Incident Title <span className="text-[#CF4500]">*</span></label>
                  <input
                    type="text"
                    required
                    value={form.title}
                    onChange={(e) => setForm({ ...form, title: e.target.value })}
                    placeholder="e.g. Commercial District Burglary"
                    className="mc-input w-full text-xs"
                  />
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-[#141413] font-medium mb-1">Crime Classification</label>
                    <select
                      value={form.crimeType}
                      onChange={(e) => setForm({ ...form, crimeType: e.target.value })}
                      className="mc-input w-full text-xs"
                    >
                      <option value="BURGLARY">Burglary / Break-in</option>
                      <option value="THEFT">Larceny / Theft</option>
                      <option value="VEHICLE_THEFT">Vehicle Theft</option>
                      <option value="SNATCHING">Chain / Mobile Snatching</option>
                      <option value="ASSAULT">Assault / Violence</option>
                      <option value="HIT_AND_RUN">Hit &amp; Run Accident</option>
                      <option value="MISSING_PERSON">Missing Person Search</option>
                      <option value="OTHER">Other Police Investigation</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-[#141413] font-medium mb-1">Search Radius (m)</label>
                    <select
                      value={form.searchRadiusMeters}
                      onChange={(e) => setForm({ ...form, searchRadiusMeters: e.target.value })}
                      className="mc-input w-full text-xs"
                    >
                      <option value="250">250m (Immediate)</option>
                      <option value="500">500m (Standard)</option>
                      <option value="1000">1000m (1 km Wide)</option>
                      <option value="2000">2000m (2 km Corridor)</option>
                    </select>
                  </div>
                </div>

                {/* Geospatial Crime Scene Point */}
                <div className="p-3.5 rounded-[24px] bg-white border border-[#E5DFD9] space-y-2.5">
                  <div className="flex items-center justify-between">
                    <span className="font-bold text-[#141413] flex items-center gap-1.5 uppercase tracking-wider text-[10px]">
                      <MapPin className="w-3.5 h-3.5 text-[#CF4500]" />
                      Crime Scene Coordinates
                    </span>
                    <div className="flex items-center gap-2">
                      <button
                        type="button"
                        onClick={handleGetCurrentGPS}
                        disabled={isLocatingGPS}
                        className="mc-btn-secondary text-[10px] py-1 px-2.5 flex items-center gap-1"
                        title="Auto-detect crime scene coordinates via device GPS sensor"
                      >
                        {isLocatingGPS ? (
                          <RefreshCw className="w-3 h-3 animate-spin text-[#CF4500]" />
                        ) : (
                          <Navigation className="w-3 h-3 text-[#3860BE]" />
                        )}
                        <span>{isLocatingGPS ? 'Locating...' : 'Auto GPS'}</span>
                      </button>
                      <button
                        type="button"
                        onClick={() => setModalMapPicker(!modalMapPicker)}
                        className={`text-[10px] py-1 px-2.5 rounded-[20px] border font-medium transition-all ${
                          modalMapPicker ? 'bg-[#141413] text-white border-[#141413]' : 'bg-white text-[#141413] border-[#141413]'
                        }`}
                      >
                        {modalMapPicker ? 'Close Map' : 'Select on Map'}
                      </button>
                    </div>
                  </div>

                  {gpsSuccess && (
                    <div className="p-2 rounded-[14px] bg-[#EAF7EE] text-[#0A7334] text-[11px] font-medium flex items-center gap-2 animate-fadeIn">
                      <Check className="w-3.5 h-3.5" />
                      <span>Crime scene coordinates auto-set to your current device GPS location.</span>
                    </div>
                  )}

                  {modalMapPicker && (
                    <div className="h-64 sm:h-72 w-full rounded-[24px] overflow-hidden my-2 border border-[#E5DFD9] relative">
                      <div className="absolute top-2.5 left-3 right-3 z-[400] pointer-events-none flex justify-center">
                        <div className="bg-[#141413]/90 backdrop-blur-xs text-[#F3F0EE] text-[11px] font-medium px-3.5 py-1 rounded-full shadow-md border border-white/10 flex items-center gap-1.5 pointer-events-auto">
                          <span className="w-2 h-2 rounded-full bg-[#CF4500] animate-ping"></span>
                          <span>Click anywhere on the map to set incident scene coordinates</span>
                        </div>
                      </div>
                      <CameraMap
                        interactivePicker={true}
                        center={[parseFloat(form.latitude) || 21.1458, parseFloat(form.longitude) || 79.0882]}
                        selectedLocation={{ lat: parseFloat(form.latitude) || 21.1458, lng: parseFloat(form.longitude) || 79.0882 }}
                        onMapClick={(a, b) => {
                          let lat, lng;
                          if (typeof a === 'object' && a !== null) {
                            lat = a.lat !== undefined ? a.lat : a.latitude;
                            lng = a.lng !== undefined ? a.lng : a.longitude;
                          } else {
                            lat = a;
                            lng = b;
                          }
                          const numLat = parseFloat(lat);
                          const numLng = parseFloat(lng);
                          if (!isNaN(numLat) && !isNaN(numLng)) {
                            setForm((prev) => ({
                              ...prev,
                              latitude: Math.round(numLat * 100000) / 100000,
                              longitude: Math.round(numLng * 100000) / 100000,
                            }));
                          }
                        }}
                        zoom={15}
                        autoFit={false}
                      />
                    </div>
                  )}

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-[#696969] font-medium mb-1">Latitude <span className="text-[#CF4500]">*</span></label>
                      <input
                        type="number"
                        step="0.00001"
                        required
                        value={form.latitude}
                        onChange={(e) => setForm({ ...form, latitude: e.target.value })}
                        className="mc-input w-full font-mono text-xs"
                      />
                    </div>
                    <div>
                      <label className="block text-[#696969] font-medium mb-1">Longitude <span className="text-[#CF4500]">*</span></label>
                      <input
                        type="number"
                        step="0.00001"
                        required
                        value={form.longitude}
                        onChange={(e) => setForm({ ...form, longitude: e.target.value })}
                        className="mc-input w-full font-mono text-xs"
                      />
                    </div>
                  </div>
                </div>

                <div>
                  <label className="block text-[#141413] font-medium mb-1">Incident Briefing</label>
                  <textarea
                    rows="2"
                    value={form.description}
                    onChange={(e) => setForm({ ...form, description: e.target.value })}
                    placeholder="Details of suspect escape route, incident timing..."
                    className="mc-input w-full rounded-[20px] text-xs"
                  ></textarea>
                </div>
              </form>
            </div>

            {/* Sticky Action Footer */}
            <div className="flex items-center justify-end gap-3 pt-3 border-t border-[#E5DFD9] bg-[#FCFBFA] sticky bottom-0 z-10">
              <button
                type="button"
                onClick={() => setShowCaseModal(false)}
                className="mc-btn-secondary"
              >
                Cancel
              </button>
              <button
                type="submit"
                form="investigationForm"
                disabled={createCaseMutation.isPending}
                className="mc-btn-primary"
              >
                {createCaseMutation.isPending ? 'Logging...' : 'Log FIR & Scan CCTV'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Close Case Modal */}
      {showDeleteModal && (
        <div className="fixed inset-0 bg-[#141413]/60 backdrop-blur-xs z-50 flex items-center justify-center p-4">
          <div className="mc-stadium max-w-md w-full p-6 sm:p-8 space-y-4 shadow-2xl bg-white">
            <h3 className="text-lg font-medium text-[#141413] border-b border-[#E5DFD9] pb-2">
              Close Police Investigation Case
            </h3>
            <p className="text-xs text-[#696969] leading-relaxed">
              Are you sure you want to close case <strong className="text-[#141413]">{activeCase?.caseNumber} - {activeCase?.title}</strong>? This will clear the active incident target and orbital radar links on the GIS map.
            </p>
            <div className="flex justify-end gap-3 pt-3 border-t border-[#E5DFD9]">
              <button
                type="button"
                onClick={() => setShowDeleteModal(false)}
                className="mc-btn-secondary"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleConfirmRemoveCase}
                className="mc-btn-signal"
              >
                Confirm Close Case
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
