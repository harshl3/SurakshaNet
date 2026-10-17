import React, { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import api from '../api/axios';
import { useAuth } from '../context/AuthContext';
import { CameraMap } from '../components/CameraMap';
import { CameraDossierModal } from '../components/CameraDossierModal';
import { 
  Camera, 
  Search, 
  Plus, 
  MapPin, 
  Eye, 
  Navigation, 
  X, 
  Map, 
  Layers, 
  User, 
  Phone, 
  ShieldCheck, 
  Lock, 
  Compass, 
  AlertTriangle,
  LayoutGrid,
  Table as TableIcon,
  ArrowRight,
  Shield,
  CheckCircle2,
  Clock
} from 'lucide-react';
import { motion } from 'framer-motion';
import { SurveyRegistrationModal } from '../components/SurveyRegistrationModal';

export const CameraList = () => {
  const { user, isAdmin, isSurveyor } = useAuth();
  const userRole = typeof user?.role === 'object' ? user?.role?.name : user?.role;
  const isUserSurveyor = isSurveyor || userRole === 'ROLE_SURVEY_PERSON';

  const queryClient = useQueryClient();

  const [searchTerm, setSearchTerm] = useState('');
  const [selectedType, setSelectedType] = useState('');
  const [selectedStatus, setSelectedStatus] = useState('');
  const [showAddModal, setShowAddModal] = useState(false);
  const [viewingCamera, setViewingCamera] = useState(null);
  const [showMapView, setShowMapView] = useState(true);
  const [useMapPicker, setUseMapPicker] = useState(false);
  const [currentLocation, setCurrentLocation] = useState(null);
  
  // Default to 'cards' on mobile (< 768px), 'table' on desktop
  const [viewMode, setViewMode] = useState(() => {
    return window.innerWidth < 768 ? 'cards' : 'table';
  });

  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          setCurrentLocation({
            lat: Math.round(pos.coords.latitude * 100000) / 100000,
            lng: Math.round(pos.coords.longitude * 100000) / 100000,
          });
        },
        (err) => console.warn('GPS auto-capture skipped:', err)
      );
    }
  }, []);

  const { data, isLoading } = useQuery({
    queryKey: ['cameras', searchTerm, selectedType, selectedStatus],
    queryFn: () => {
      let params = new URLSearchParams();
      if (searchTerm) params.append('query', searchTerm);
      if (selectedType) params.append('cameraType', selectedType);
      if (selectedStatus) params.append('cameraStatus', selectedStatus);
      params.append('size', '1000');
      return api.get(`/cameras/search?${params.toString()}`);
    },
    refetchInterval: 3000,
  });

  const [errorMessage, setErrorMessage] = useState('');

  const getInitialForm = () => ({
    cameraCode: `CAM-${Date.now().toString().slice(-5)}${Math.floor(10 + Math.random() * 90)}`,
    cameraName: 'Surveyed CCTV Camera Point',
    cameraType: 'PTZ',
    latitude: 21.1458,
    longitude: 79.0882,
    city: 'Nagpur',
    state: 'Maharashtra',
    area: 'Central Zone',
    fullAddress: 'Main Market Road, Nagpur',
    cardinalDirection: 'EAST',
    directionAngle: 90,
    coverageRadiusMeters: 100,
    fovAngle: 60,
    ownerName: 'Commercial Store Owner',
    ownerContact: '+91 9876543210',
    ownerType: 'COMMERCIAL',
  });

  const [form, setForm] = useState(getInitialForm());

  useEffect(() => {
    if (showAddModal) {
      setForm(getInitialForm());
      setErrorMessage('');
      if (navigator.geolocation) {
        try {
          navigator.geolocation.getCurrentPosition(
            (pos) => {
              const lat = pos?.coords?.latitude;
              const lng = pos?.coords?.longitude;
              if (typeof lat === 'number' && !isNaN(lat) && typeof lng === 'number' && !isNaN(lng)) {
                setForm((prev) => ({
                  ...prev,
                  latitude: Math.round(lat * 100000) / 100000,
                  longitude: Math.round(lng * 100000) / 100000,
                }));
              }
            },
            (err) => console.warn('GPS auto-capture skipped:', err)
          );
        } catch (e) {}
      }
    }
  }, [showAddModal]);

  const addCameraMutation = useMutation({
    mutationFn: (newCam) => api.post('/cameras', newCam),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cameras'] });
      queryClient.invalidateQueries({ queryKey: ['nearby-cameras-all'] });
      queryClient.invalidateQueries({ queryKey: ['pending-cameras'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard-stats'] });
      queryClient.invalidateQueries({ queryKey: ['my-surveyed-cameras'] });
      setShowAddModal(false);
      setErrorMessage('');
      setForm(getInitialForm());
    },
    onError: (err) => {
      const msg = err.response?.data?.message || err.message || 'Failed to submit camera survey. Please verify fields.';
      setErrorMessage(msg);
    },
  });

  const handleCreateSubmit = (e) => {
    e.preventDefault();
    setErrorMessage('');
    if (!form.cameraName || !form.latitude || !form.longitude) {
      setErrorMessage('Please fill in Camera Name and valid GPS coordinates.');
      return;
    }
    addCameraMutation.mutate({
      ...form,
      latitude: parseFloat(form.latitude),
      longitude: parseFloat(form.longitude),
      directionAngle: parseFloat(form.directionAngle) || 0,
      coverageRadiusMeters: parseFloat(form.coverageRadiusMeters) || 100,
    });
  };

  const handleGetCurrentGPS = () => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setForm((prev) => ({
            ...prev,
            latitude: Math.round(position.coords.latitude * 100000) / 100000,
            longitude: Math.round(position.coords.longitude * 100000) / 100000,
          }));
        },
        () => alert('GPS capture timed out.')
      );
    }
  };

  const handleMapLocationSelect = (a, b) => {
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
      setForm((prev) => ({
        ...prev,
        latitude: roundedLat,
        longitude: roundedLng,
      }));
    }
  };

  const cameras = data?.data?.content || [];

  return (
    <div className="space-y-6 md:space-y-8">
      {/* Top Police GIS Registry Banner */}
      <div className="mc-stadium p-5 sm:p-7 md:p-8 flex flex-col md:flex-row md:items-center justify-between gap-5 relative overflow-hidden">
        <div className="absolute right-0 top-1/2 -translate-y-1/2 text-[100px] md:text-[140px] font-bold text-[#E8E2DA]/40 select-none pointer-events-none tracking-[-0.04em] pr-4">
          CCTV GIS
        </div>

        <div className="relative z-10 max-w-2xl space-y-2">
          <div className="mc-eyebrow">
            <span className="mc-eyebrow-dot"></span>
            <span>POLICE SURVEILLANCE INFRASTRUCTURE</span>
          </div>

          <h1 className="text-2xl sm:text-3xl md:text-4xl font-medium text-[#141413] tracking-[-0.02em] leading-tight">
            Metropolitan CCTV Camera Registry
          </h1>

          <p className="text-sm md:text-base text-[#696969] font-normal leading-relaxed">
            Geocoded surveillance nodes, directional coverage angles, optical specs, and civilian/police camera owners for crime investigation.
          </p>
        </div>

        <div className="relative z-10 flex flex-wrap items-center gap-3 shrink-0">
          <button
            onClick={() => setShowMapView(!showMapView)}
            className={`mc-btn-secondary ${showMapView ? 'bg-[#141413] text-[#FCFBFA]' : ''}`}
          >
            <Map className="w-4 h-4" />
            <span>{showMapView ? 'Hide GIS Radar' : 'Show GIS Radar'}</span>
          </button>

          <button
            onClick={() => setShowAddModal(true)}
            className="mc-btn-primary"
          >
            <Plus className="w-4 h-4 text-[#F37338]" />
            <span>Survey New Camera</span>
          </button>
        </div>
      </div>

      {/* Embedded Police GIS Map Radar (Collapsible) */}
      {showMapView && (
        <motion.div
          initial={{ opacity: 0, height: 0 }}
          animate={{ opacity: 1, height: 'auto' }}
          className="mc-stadium p-4 sm:p-6 md:p-7 space-y-3"
        >
          <div className="flex items-center justify-between border-b border-[#E5DFD9] pb-3">
            <div className="mc-eyebrow">
              <span className="mc-eyebrow-dot"></span>
              <span>LIVE GEOSPATIAL CCTV RECONNAISSANCE</span>
            </div>
            <span className="text-xs font-mono font-medium text-[#696969]">
              {cameras.length} nodes plotted
            </span>
          </div>

          <div className="h-[320px] sm:h-[420px] md:h-[480px] w-full relative rounded-[24px] sm:rounded-[32px] overflow-hidden border border-[#E5DFD9] bg-[#F3F0EE]">
            <CameraMap
              cameras={cameras}
              center={[21.1458, 79.0882]}
              zoom={13.5}
              selectedCameraId={viewingCamera?.id}
              onSelectCamera={(cam) => setViewingCamera(cam)}
              autoFit={false}
            />
          </div>
        </motion.div>
      )}

      {/* Search & Filter Controls: Responsive Stadium Card on Mobile, Continuous Pill Bar on Desktop */}
      <div className="bg-white border border-[#E5DFD9] rounded-[24px] md:rounded-full p-2.5 sm:p-3 md:p-2 shadow-mc-card flex flex-col md:flex-row items-center justify-between gap-2.5 md:gap-3">
        {/* Search Input */}
        <div className="relative flex-1 w-full flex items-center bg-[#F3F0EE]/60 md:bg-transparent rounded-full px-3.5 py-1.5 md:py-0 border border-[#E5DFD9] md:border-0">
          <Search className="w-4 h-4 text-[#696969] shrink-0" />
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Search by camera code, area, landmark, owner name..."
            className="w-full bg-transparent text-xs sm:text-sm text-[#141413] placeholder-[#696969] px-2.5 py-1 focus:outline-none"
          />
          {searchTerm && (
            <button 
              onClick={() => setSearchTerm('')} 
              aria-label="Clear search input"
              className="text-[#696969] hover:text-[#141413] pl-1"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        {/* Filter Dropdowns & View Mode Toggles (Single clean horizontal row on mobile) */}
        <div className="flex items-center justify-between w-full md:w-auto gap-2 px-1 md:px-0">
          <div className="flex items-center gap-2 flex-1 md:flex-none">
            <select
              value={selectedType}
              onChange={(e) => setSelectedType(e.target.value)}
              aria-label="Filter by Camera Hardware Type"
              className="mc-input text-xs py-1.5 px-2.5 sm:px-3 font-medium border-[#D1CDC7] text-[#141413] bg-[#FCFBFA] flex-1 md:flex-none max-w-[150px] sm:max-w-none truncate"
            >
              <option value="">All Hardware</option>
              <option value="PTZ">PTZ</option>
              <option value="DOME">Dome</option>
              <option value="BULLET">Bullet</option>
              <option value="ANPR">ANPR</option>
            </select>

            <select
              value={selectedStatus}
              onChange={(e) => setSelectedStatus(e.target.value)}
              aria-label="Filter by Live Stream Status"
              className="mc-input text-xs py-1.5 px-2.5 sm:px-3 font-medium border-[#D1CDC7] text-[#141413] bg-[#FCFBFA] flex-1 md:flex-none max-w-[140px] sm:max-w-none truncate"
            >
              <option value="">All Statuses</option>
              <option value="ACTIVE">Online</option>
              <option value="OFFLINE">Offline</option>
            </select>
          </div>

          {/* Cards vs Table Pill Toggle */}
          <div className="flex items-center bg-[#F3F0EE] p-1 rounded-full border border-[#D1CDC7] shrink-0 ml-auto">
            <button
              onClick={() => setViewMode('cards')}
              className={`p-1.5 rounded-full transition-all ${
                viewMode === 'cards' 
                  ? 'bg-white text-[#141413] shadow-xs' 
                  : 'text-[#696969] hover:text-[#141413]'
              }`}
              title="Portrait Cards View"
            >
              <LayoutGrid className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
            </button>
            <button
              onClick={() => setViewMode('table')}
              className={`p-1.5 rounded-full transition-all ${
                viewMode === 'table' 
                  ? 'bg-white text-[#141413] shadow-xs' 
                  : 'text-[#696969] hover:text-[#141413]'
              }`}
              title="Registry Table View"
            >
              <TableIcon className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
            </button>
          </div>
        </div>
      </div>

      {/* Results Header Count */}
      <div className="flex items-center justify-between px-2">
        <p className="text-xs font-medium text-[#696969]">
          Showing <span className="font-bold text-[#141413]">{cameras.length}</span> registered police surveillance nodes
        </p>
      </div>

      {/* Content: Cards View vs Table View */}
      {viewMode === 'cards' ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 md:gap-5">
          {isLoading ? (
            <div className="col-span-full mc-stadium p-12 text-center text-[#696969]">
              <div className="animate-pulse space-y-3 max-w-sm mx-auto">
                <div className="h-5 bg-[#E5DFD9] rounded-full w-2/3 mx-auto"></div>
                <div className="h-4 bg-[#E5DFD9] rounded-full w-1/2 mx-auto"></div>
              </div>
            </div>
          ) : cameras.length === 0 ? (
            <div className="col-span-full mc-stadium p-12 text-center space-y-3">
              <Camera className="w-12 h-12 text-[#696969] mx-auto opacity-50" />
              <h3 className="text-lg font-medium text-[#141413]">No CCTV Cameras Found</h3>
              <p className="text-xs text-[#696969] max-w-sm mx-auto">
                No surveillance nodes matched your current filter criteria.
              </p>
            </div>
          ) : (
            cameras.map((cam, idx) => (
              <motion.div
                key={cam.id}
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: idx * 0.02 }}
                className="mc-card p-5 flex flex-col justify-between group hover:border-[#D1CDC7] hover:shadow-mc-elevated transition-all duration-200"
              >
                <div className="space-y-4">
                  {/* Mastercard Circular Portrait with Attached White Satellite Micro-CTA */}
                  <div className="flex items-center justify-center pt-2">
                    <div className="relative w-28 h-28 sm:w-32 sm:h-32">
                      {/* Circular Camera Mask */}
                      <div className="w-full h-full rounded-full bg-[#F3F0EE] border-2 border-[#E5DFD9] flex flex-col items-center justify-center text-center p-3 shadow-inner overflow-hidden group-hover:scale-[1.02] transition-transform">
                        <Camera className="w-7 h-7 text-[#141413] mb-1" />
                        <span className="font-mono text-[10px] font-bold text-[#141413] uppercase tracking-wider">{cam.cameraType}</span>
                        <span className={`text-[9px] font-semibold mt-0.5 ${cam.cameraStatus === 'ACTIVE' ? 'text-[#0A7334]' : 'text-[#CF4500]'}`}>
                          {cam.cameraStatus === 'ACTIVE' ? '● ONLINE' : '● OFFLINE'}
                        </span>
                      </div>

                      {/* Docked White Satellite CTA Button (Moon motif) */}
                      <button
                        onClick={() => setViewingCamera(cam)}
                        className="satellite-cta absolute -bottom-1 -right-1"
                        title="Inspect Camera Specs"
                      >
                        <ArrowRight className="w-4 h-4" />
                      </button>
                    </div>
                  </div>

                  {/* Eyebrow Label with Accent Dot */}
                  <div className="text-center space-y-1">
                    <div className="mc-eyebrow justify-center text-[10px]">
                      <span className="mc-eyebrow-dot"></span>
                      <span>SURVEILLANCE NODE</span>
                    </div>

                    <h3 className="text-base font-medium text-[#141413] tracking-[-0.02em] line-clamp-1">
                      {cam.cameraName}
                    </h3>

                    <p className="text-xs font-mono text-[#696969]">{cam.cameraCode}</p>
                  </div>

                  {/* Location & Specs */}
                  <div className="space-y-2 pt-2 border-t border-[#E5DFD9] text-xs">
                    <div className="flex items-center gap-1.5 text-[#696969]">
                      <MapPin className="w-3.5 h-3.5 text-[#CF4500] shrink-0" />
                      <span className="truncate">{cam.fullAddress || cam.area || 'Nagpur Central'}</span>
                    </div>

                    <div className="grid grid-cols-2 gap-2 p-2.5 rounded-[16px] bg-[#F3F0EE] text-[11px]">
                      <div>
                        <span className="text-[#696969] block text-[9px] uppercase tracking-wider font-semibold">Orientation</span>
                        <strong className="text-[#141413]">{cam.directionAngle}° ({cam.cardinalDirection || 'EAST'})</strong>
                      </div>
                      <div>
                        <span className="text-[#696969] block text-[9px] uppercase tracking-wider font-semibold">Radar Arc</span>
                        <strong className="text-[#141413]">{cam.coverageRadiusMeters}m</strong>
                      </div>
                    </div>

                    {!isUserSurveyor && (
                      <div className="p-2 rounded-[14px] bg-white border border-[#E5DFD9] text-[11px] flex items-center justify-between">
                        <div className="truncate pr-2">
                          <span className="text-[#696969] text-[9px] block uppercase tracking-wider font-medium">Owner</span>
                          <span className="font-semibold text-[#141413] truncate block">
                            {cam.ownerName || 'Govt / Police Dept'}
                          </span>
                        </div>
                        {cam.ownerContact && (
                          <a 
                            href={`tel:${cam.ownerContact}`}
                            className="font-mono text-[#3860BE] font-semibold text-[10px] flex items-center gap-1 shrink-0 hover:underline"
                          >
                            <Phone className="w-3 h-3" />
                            <span>Call</span>
                          </a>
                        )}
                      </div>
                    )}
                  </div>
                </div>

                {/* Bottom Verification Status Pill & Action */}
                <div className="pt-3 mt-3 border-t border-[#E5DFD9] flex items-center justify-between">
                  <span className={cam.verificationStatus === 'APPROVED' ? 'badge-approved' : 'badge-pending'}>
                    {cam.verificationStatus === 'APPROVED' ? '✓ Verified' : '◷ Pending'}
                  </span>

                  <button
                    onClick={() => setViewingCamera(cam)}
                    className="mc-btn-secondary text-xs py-1 px-3"
                  >
                    <Eye className="w-3.5 h-3.5 text-[#3860BE]" />
                    <span>Inspect</span>
                  </button>
                </div>
              </motion.div>
            ))
          )}
        </div>
      ) : (
        /* Table View */
        <div className="mc-stadium overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-[#F3F0EE] text-[#696969] font-bold uppercase tracking-[+0.04em] border-b border-[#E5DFD9]">
                <tr>
                  <th className="p-4">Camera Code</th>
                  <th className="p-4">Name &amp; Location</th>
                  {!isUserSurveyor && <th className="p-4">Owner &amp; Contact</th>}
                  <th className="p-4">Type</th>
                  <th className="p-4">Radius / Angle</th>
                  <th className="p-4">Status</th>
                  <th className="p-4">Verification</th>
                  <th className="p-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[#E5DFD9] text-[#141413]">
                {isLoading ? (
                  <tr>
                    <td colSpan={isUserSurveyor ? "7" : "8"} className="p-8 text-center text-[#696969]">
                      Loading surveillance registry...
                    </td>
                  </tr>
                ) : cameras.length === 0 ? (
                  <tr>
                    <td colSpan={isUserSurveyor ? "7" : "8"} className="p-8 text-center text-[#696969]">
                      No cameras match your search parameters.
                    </td>
                  </tr>
                ) : (
                  cameras.map((cam) => (
                    <tr key={cam.id} className="hover:bg-white/80 transition-colors">
                      <td className="p-4 font-mono font-bold text-[#141413]">{cam.cameraCode}</td>
                      <td className="p-4">
                        <div className="font-semibold text-[#141413]">{cam.cameraName}</div>
                        <div className="text-[11px] text-[#696969] flex items-center gap-1 mt-0.5">
                          <MapPin className="w-3 h-3 text-[#CF4500] shrink-0" />
                          <span className="truncate max-w-xs">{cam.fullAddress || cam.area}</span>
                        </div>
                      </td>
                      {!isUserSurveyor && (
                        <td className="p-4">
                          <div className="font-medium text-[#141413] flex items-center gap-1">
                            <User className="w-3 h-3 text-[#3860BE]" />
                            <span>{cam.ownerName || 'Govt / Police Dept'}</span>
                          </div>
                          {cam.ownerContact && (
                            <div className="text-[11px] text-[#696969] flex items-center gap-1 font-mono">
                              <Phone className="w-3 h-3 text-[#696969]" />
                              {cam.ownerContact}
                            </div>
                          )}
                        </td>
                      )}
                      <td className="p-4">
                        <span className="bg-[#F3F0EE] border border-[#D1CDC7] px-2.5 py-0.5 rounded-full text-[10px] font-mono font-semibold text-[#141413]">
                          {cam.cameraType}
                        </span>
                      </td>
                      <td className="p-4 text-[11px]">
                        <div>{cam.coverageRadiusMeters}m radius</div>
                        <div className="text-[#696969] font-medium">{cam.directionAngle}° ({cam.cardinalDirection})</div>
                      </td>
                      <td className="p-4">
                        <span className={cam.cameraStatus === 'ACTIVE' ? 'badge-active' : 'badge-offline'}>
                          {cam.cameraStatus === 'ACTIVE' ? '● Online' : '● Offline'}
                        </span>
                      </td>
                      <td className="p-4">
                        <span className={cam.verificationStatus === 'APPROVED' ? 'badge-approved' : 'badge-pending'}>
                          {cam.verificationStatus === 'APPROVED' ? '✓ Approved' : '◷ Pending'}
                        </span>
                      </td>
                      <td className="p-4 text-right">
                        <button
                          onClick={() => setViewingCamera(cam)}
                          className="mc-btn-secondary text-[11px] py-1 px-3 ml-auto"
                        >
                          <Eye className="w-3.5 h-3.5 text-[#3860BE]" />
                          <span>Details</span>
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* CCTV Node Dossier Modal for surveyors when map is hidden */}
      {isUserSurveyor && viewingCamera && (
        <CameraDossierModal
          camera={viewingCamera}
          onClose={() => setViewingCamera(null)}
          isSurveyor={true}
        />
      )}

      {/* Add Camera Survey Registration Modal */}
      <SurveyRegistrationModal
        isOpen={showAddModal}
        onClose={() => setShowAddModal(false)}
      />
    </div>
  );
};
