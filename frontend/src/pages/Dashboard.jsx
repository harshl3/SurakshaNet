import React, { useState, useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import api from '../api/axios';
import { useAuth } from '../context/AuthContext';
import { CameraMap } from '../components/CameraMap';
import { 
  Camera, 
  CheckCircle, 
  AlertTriangle, 
  FileSearch, 
  Building2, 
  Eye, 
  Navigation, 
  Target, 
  ArrowUpRight,
  Info,
  Shield,
  Radio,
  Clock
} from 'lucide-react';
import { motion } from 'framer-motion';

export const Dashboard = () => {
  const { user, isAdmin, isOfficer } = useAuth();
  const navigate = useNavigate();
  const userRole = typeof user?.role === 'object' ? user?.role?.name : user?.role;
  const isUserAdmin = isAdmin || userRole === 'ROLE_ADMIN';
  const isUserOfficer = isOfficer || userRole === 'ROLE_POLICE_OFFICER';

  const [currentLocation, setCurrentLocation] = useState(null);
  const [selectedCaseId, setSelectedCaseId] = useState(null);
  const [selectedCamera, setSelectedCamera] = useState(null);
  const [showMapLegend, setShowMapLegend] = useState(false);

  // Auto-fetch system GPS location on mount
  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setCurrentLocation({
            lat: Math.round(position.coords.latitude * 100000) / 100000,
            lng: Math.round(position.coords.longitude * 100000) / 100000,
          });
        },
        (error) => {
          console.warn('System GPS auto-capture skipped:', error);
        }
      );
    }
  }, []);

  // Query System KPI Stats for Admin
  const { data: statsData, isLoading: isStatsLoading } = useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: () => api.get('/dashboard/stats'),
    enabled: isUserAdmin,
    refetchInterval: 3000,
  });

  // Query All CCTV Cameras for Map
  const { data: cameraData } = useQuery({
    queryKey: ['nearby-cameras-all'],
    queryFn: async () => {
      const res = await api.get('/cameras/search?size=1000');
      return res?.data?.content || [];
    },
    refetchInterval: 3000,
  });

  // Query Police Station Headquarters for Map
  const { data: stationsData } = useQuery({
    queryKey: ['police-stations'],
    queryFn: () => api.get('/stations').catch(() => null),
    refetchInterval: 10000,
  });

  // Query Active Investigation Cases
  const { data: casesData } = useQuery({
    queryKey: ['dashboard-investigations'],
    queryFn: async () => {
      const res = await api.get('/investigations?size=100').catch(() => null);
      return res?.data?.content || [];
    },
    refetchInterval: 3000,
  });

  const handleFetchCurrentGPS = () => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setCurrentLocation({
            lat: Math.round(position.coords.latitude * 100000) / 100000,
            lng: Math.round(position.coords.longitude * 100000) / 100000,
          });
        },
        () => {
          alert('GPS location capture failed. Map will display overall metropolitan CCTV network.');
        }
      );
    }
  };

  const stats = statsData?.data || {};
  const cameras = cameraData || [];
  const stations = stationsData?.data?.content || stationsData?.data || [];
  const rawCases = casesData || [];

  // Filter investigations based on officer authorization
  const availableCases = rawCases.filter((c) => {
    if (isUserAdmin) return true;
    return (
      c.assignedOfficerId === user?.id ||
      c.assignedOfficerName === user?.fullName ||
      c.createdBy === user?.username
    );
  });

  const activeCase = availableCases.find((c) => c.id === selectedCaseId) || availableCases[0];

  const crimeLocationProps = activeCase?.latitude && activeCase?.longitude ? {
    lat: activeCase.latitude,
    lng: activeCase.longitude,
    name: `${activeCase.caseNumber} - ${activeCase.title}`
  } : null;

  const cards = [
    { 
      title: 'Total CCTV Cameras', 
      value: stats.totalCameras || cameras.length || 0, 
      icon: Camera, 
      accent: 'bg-[#141413] text-[#FCFBFA]', 
      path: '/cameras',
      sublabel: 'Surveillance network'
    },
    { 
      title: 'Active Live Stream', 
      value: stats.activeCameras || cameras.filter(c => c.cameraStatus === 'ACTIVE').length || 0, 
      icon: Eye, 
      accent: 'bg-[#EAF7EE] text-[#0A7334]', 
      path: '/cameras',
      sublabel: 'Online & healthy'
    },
    { 
      title: 'Offline / Maintenance', 
      value: stats.offlineCameras || cameras.filter(c => c.cameraStatus === 'OFFLINE').length || 0, 
      icon: AlertTriangle, 
      accent: 'bg-[#FDF0EE] text-[#CF4500]', 
      path: '/cameras',
      sublabel: 'Requires attention'
    },
    { 
      title: 'Pending Verification', 
      value: stats.pendingVerificationCameras || 0, 
      icon: CheckCircle, 
      accent: 'bg-[#FEF6E9] text-[#B56708]', 
      path: '/verification',
      sublabel: 'Awaiting police review'
    },
    { 
      title: 'Active Investigations', 
      value: stats.openCases || availableCases.length, 
      icon: FileSearch, 
      accent: 'bg-[#EEF2FC] text-[#3860BE]', 
      path: '/investigations',
      sublabel: 'Active crime dossiers'
    },
    { 
      title: 'Police Stations HQ', 
      value: stats.totalPoliceStations || stations.length || 6, 
      icon: Building2, 
      accent: 'bg-[#F3F0EE] text-[#141413]', 
      path: '/dashboard',
      sublabel: 'Jurisdiction precincts'
    },
  ];

  return (
    <div className="space-y-6 md:space-y-8">
      {/* Top Police Command Stadium Banner */}
      <div className="mc-stadium p-5 sm:p-7 md:p-8 flex flex-col md:flex-row md:items-center justify-between gap-5 relative overflow-hidden">
        {/* Subtle Watermark Branding */}
        <div className="absolute right-0 top-1/2 -translate-y-1/2 text-[100px] md:text-[140px] font-bold text-[#E8E2DA]/40 select-none pointer-events-none tracking-[-0.04em] pr-4">
          POLICE GIS
        </div>

        <div className="relative z-10 max-w-2xl space-y-2">
          <div className="mc-eyebrow">
            <span className="mc-eyebrow-dot"></span>
            <span>POLICE GIS COMMAND</span>
          </div>

          <h1 className="text-2xl sm:text-3xl md:text-4xl font-medium text-[#141413] tracking-[-0.02em] leading-tight">
            {isUserAdmin ? 'Police GIS Command Center' : 'Patrol CCTV Live Map'}
          </h1>

          <p className="text-sm md:text-base text-[#696969] font-normal leading-relaxed">
            {isUserAdmin 
              ? 'Real-time CCTV telemetry, police precincts, and crime scene mapping.'
              : 'Real-time CCTV camera reconnaissance and crime incident coverage.'}
          </p>
        </div>

        <div className="relative z-10 flex flex-wrap items-center gap-3 shrink-0">
          <button
            onClick={handleFetchCurrentGPS}
            className="mc-btn-primary"
          >
            <Navigation className="w-4 h-4 text-[#F37338]" />
            <span>My Current GPS</span>
          </button>
          
          <button
            onClick={() => setShowMapLegend(!showMapLegend)}
            className={`mc-btn-secondary ${showMapLegend ? 'bg-[#141413] text-[#FCFBFA]' : ''}`}
          >
            <Info className="w-4 h-4" />
            <span>Map Legend</span>
          </button>
        </div>
      </div>

      {/* KPI Cards: 2 boxes per row on mobile, 3 on tablet, 6 on desktop */}
      {isUserAdmin && (
        <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-2.5 sm:gap-3.5 md:gap-4">
          {cards.map((card, idx) => {
            const Icon = card.icon;
            return (
              <motion.div
                key={card.title}
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: idx * 0.04 }}
                onClick={() => card.path && navigate(card.path)}
                className="mc-card p-3 sm:p-4 md:p-5 cursor-pointer hover:shadow-mc-elevated hover:border-[#D1CDC7] transition-all duration-200 flex flex-col justify-between group min-h-[125px] sm:min-h-[148px]"
              >
                <div>
                  <div className="flex items-center justify-between gap-1.5 sm:gap-2">
                    <span className="text-[11px] sm:text-xs font-semibold text-[#696969] tracking-[-0.01em] line-clamp-1">{card.title}</span>
                    <div className={`w-7 h-7 sm:w-8 sm:h-8 rounded-full flex items-center justify-center shrink-0 ${card.accent}`}>
                      <Icon className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                    </div>
                  </div>

                  <p className="text-xl sm:text-2xl md:text-3xl font-medium text-[#141413] mt-2 sm:mt-3 tracking-[-0.02em]">
                    {isStatsLoading ? '...' : card.value}
                  </p>
                </div>

                <div className="flex items-center justify-between pt-2 sm:pt-3 mt-1.5 sm:mt-2 border-t border-[#E5DFD9] text-[10px] sm:text-[11px] text-[#696969]">
                  <span className="truncate pr-1">{card.sublabel}</span>
                  <div className="w-5 h-5 sm:w-6 sm:h-6 rounded-full bg-white border border-[#E5DFD9] flex items-center justify-center group-hover:bg-[#141413] group-hover:text-white transition-colors shrink-0">
                    <ArrowUpRight className="w-3 h-3 sm:w-3.5 sm:h-3.5" />
                  </div>
                </div>
              </motion.div>
            );
          })}
        </div>
      )}

      {/* Live Map Stadium Frame */}
      <div className="mc-stadium p-4 sm:p-6 md:p-7 flex flex-col gap-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-[#E5DFD9] pb-4">
          <div className="space-y-1">
            <div className="mc-eyebrow">
              <span className="mc-eyebrow-dot"></span>
              <span>GEOSPATIAL RADAR NETWORK</span>
            </div>
            <div className="flex items-center gap-2">
              <h2 className="text-lg md:text-xl font-medium text-[#141413] tracking-[-0.02em]">
                Metropolitan CCTV &amp; Police Precinct Infrastructure
              </h2>
              <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-mono font-medium bg-white text-[#141413] border border-[#D1CDC7]">
                {cameras.length} nodes online
              </span>
            </div>
          </div>

          {/* Incident Target Focus Dropdown */}
          {availableCases.length > 0 && (
            <div className="flex items-center gap-2 w-full sm:w-auto">
              <span className="text-xs text-[#CF4500] font-bold flex items-center gap-1 shrink-0 uppercase tracking-wider">
                <Target className="w-4 h-4 text-[#CF4500]" /> Crime Target:
              </span>
              <select
                value={activeCase?.id || ''}
                onChange={(e) => setSelectedCaseId(Number(e.target.value))}
                aria-label="Filter Map By Crime Target"
                className="mc-input text-xs py-2 px-3 font-medium border-[#D1CDC7] text-[#141413] focus:border-[#141413] w-full sm:w-auto max-w-xs"
              >
                {availableCases.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.caseNumber} - {c.title}
                  </option>
                ))}
              </select>
            </div>
          )}
        </div>

        {/* Map Legend Banner (Collapsible) */}
        {showMapLegend && (
          <motion.div 
            initial={{ opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            className="p-4 rounded-[20px] bg-white border border-[#E5DFD9] text-xs flex flex-wrap items-center gap-4 sm:gap-6 text-[#141413]"
          >
            <span className="font-bold text-[11px] uppercase tracking-wider text-[#696969]">Legend:</span>
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded-full bg-[#10B981]"></span>
              <span className="font-medium">Active CCTV</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded-full bg-[#CF4500]"></span>
              <span className="font-medium">Offline CCTV</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded-full bg-[#F59E0B]"></span>
              <span className="font-medium">Pending Survey</span>
            </div>
            <div className="flex items-center gap-2">
              <img src="/police-station-marker.png" alt="Police Station HQ" className="w-3.5 h-4 object-contain shrink-0" />
              <span className="font-medium">Police Station HQ</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded-full bg-[#CF4500] ring-2 ring-[#F37338]"></span>
              <span className="font-medium">Crime Target (FIR)</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="w-6 h-0.5 border-t-2 border-dashed border-[#F37338]"></span>
              <span className="font-medium">Investigation Radar Trajectory</span>
            </div>
          </motion.div>
        )}

        {/* Leaflet Map in 40px Stadium Container Frame */}
        <div className="h-[420px] sm:h-[500px] md:h-[620px] w-full relative rounded-[28px] sm:rounded-[36px] md:rounded-[40px] overflow-hidden border border-[#E5DFD9] shadow-mc-card bg-[#F3F0EE]">
          <CameraMap 
            cameras={cameras} 
            stations={stations}
            center={activeCase?.latitude && activeCase?.longitude ? [activeCase.latitude, activeCase.longitude] : [21.1458, 79.0882]}
            zoom={15}
            crimeLocation={crimeLocationProps}
            searchRadius={activeCase?.searchRadiusMeters || 500}
            selectedCameraId={selectedCamera?.id}
            onSelectCamera={(cam) => setSelectedCamera(cam)}
            autoFit={true}
            focusKey={activeCase?.id}
          />
        </div>
      </div>
    </div>
  );
};
