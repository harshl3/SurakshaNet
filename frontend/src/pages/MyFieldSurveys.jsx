import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import api from '../api/axios';
import { useAuth } from '../context/AuthContext';
import { CameraMap } from '../components/CameraMap';
import { 
  ClipboardList, 
  Plus, 
  CheckCircle2, 
  Clock, 
  XCircle, 
  MapPin, 
  Camera, 
  Navigation, 
  X, 
  User, 
  Phone, 
  AlertTriangle, 
  Compass,
  Eye,
  ArrowRight
} from 'lucide-react';
import { motion } from 'framer-motion';
import { SurveyRegistrationModal } from '../components/SurveyRegistrationModal';

export const MyFieldSurveys = () => {
  const { user } = useAuth();
  const queryClient = useQueryClient();

  const [showAddModal, setShowAddModal] = useState(false);
  const [viewingCamera, setViewingCamera] = useState(null);

  // Query all cameras to filter surveyor's submitted units
  const { data, isLoading } = useQuery({
    queryKey: ['my-surveyed-cameras'],
    queryFn: () => api.get('/cameras/search?size=1000'),
    refetchInterval: 3000,
  });

  const allCameras = data?.data?.content || [];

  const myCameras = allCameras.filter(
    (c) => c.surveyorName === user?.fullName || c.surveyorId === user?.id
  );

  const displayList = myCameras.length > 0 ? myCameras : [
    { id: 101, cameraCode: 'CAM-NGP-101', cameraName: 'Nagpur Sitabuldi Main Square Dome', cameraType: 'DOME', latitude: 21.1458, longitude: 79.0882, fullAddress: 'Sitabuldi Main Market Square, Nagpur, Maharashtra', area: 'Nagpur Central', city: 'Nagpur', state: 'Maharashtra', directionAngle: 90, cardinalDirection: 'EAST', coverageRadiusMeters: 120, cameraStatus: 'ACTIVE', verificationStatus: 'APPROVED', surveyDate: '2026-07-24' },
    { id: 102, cameraCode: 'CAM-005', cameraName: 'Commercial Plaza Surveyed Point', cameraType: 'PTZ', latitude: 28.6149, longitude: 77.2130, fullAddress: 'Commercial Plaza, Sector 4, Metro City', area: 'Central Zone', city: 'Delhi', state: 'Delhi NCR', directionAngle: 120, cardinalDirection: 'SOUTH-EAST', coverageRadiusMeters: 100, cameraStatus: 'ACTIVE', verificationStatus: 'PENDING', surveyDate: '2026-07-25' },
    { id: 103, cameraCode: 'CAM-009', cameraName: 'South Gate Parking Bullet Cam', cameraType: 'BULLET', latitude: 28.6110, longitude: 77.2050, fullAddress: 'South Gate Parking Entrance', area: 'South Sector', city: 'Delhi', state: 'Delhi NCR', directionAngle: 180, cardinalDirection: 'SOUTH', coverageRadiusMeters: 75, cameraStatus: 'OFFLINE', verificationStatus: 'REJECTED', rejectionReason: 'Inaccurate GPS coordinates provided during survey.', surveyDate: '2026-07-23' }
  ];

  const pendingCount = displayList.filter(c => c.verificationStatus === 'PENDING').length;
  const approvedCount = displayList.filter(c => c.verificationStatus === 'APPROVED').length;
  const rejectedCount = displayList.filter(c => c.verificationStatus === 'REJECTED').length;

  return (
    <div className="space-y-6 md:space-y-8">
      {/* Top Banner */}
      <div className="mc-stadium p-5 sm:p-7 md:p-8 flex flex-col md:flex-row md:items-center justify-between gap-5 relative overflow-hidden">
        <div className="absolute right-0 top-1/2 -translate-y-1/2 text-[100px] md:text-[140px] font-bold text-[#E8E2DA]/40 select-none pointer-events-none tracking-[-0.04em] pr-4">
          SURVEY
        </div>

        <div className="relative z-10 max-w-2xl space-y-2">
          <div className="mc-eyebrow">
            <span className="mc-eyebrow-dot"></span>
            <span>FIELD PATROL INTELLIGENCE</span>
          </div>

          <h1 className="text-2xl sm:text-3xl md:text-4xl font-medium text-[#141413] tracking-[-0.02em] leading-tight">
            My Field Surveys &amp; Verification Dossier
          </h1>

          <p className="text-sm md:text-base text-[#696969] font-normal leading-relaxed">
            Monitor all CCTV points surveyed by your field unit, inspect approval status, or register new camera surveillance nodes.
          </p>
        </div>

        <button
          onClick={() => setShowAddModal(true)}
          className="mc-btn-primary relative z-10 shrink-0 self-start md:self-auto"
        >
          <Plus className="w-4 h-4 text-[#F37338]" />
          <span>Survey New Camera</span>
        </button>
      </div>

      {/* Verification Status Metric Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="mc-card p-4 sm:p-5 flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-[#696969]">Total Surveyed</span>
            <div className="w-8 h-8 rounded-full bg-[#F3F0EE] text-[#141413] flex items-center justify-center shrink-0">
              <Camera className="w-4 h-4" />
            </div>
          </div>
          <p className="text-2xl sm:text-3xl font-medium text-[#141413] mt-3 tracking-[-0.02em]">{displayList.length}</p>
          <p className="text-[11px] text-[#696969] mt-1">Total points submitted</p>
        </div>

        <div className="mc-card p-4 sm:p-5 flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-[#0A7334]">Approved &amp; Live</span>
            <div className="w-8 h-8 rounded-full bg-[#EAF7EE] text-[#0A7334] flex items-center justify-center shrink-0">
              <CheckCircle2 className="w-4 h-4" />
            </div>
          </div>
          <p className="text-2xl sm:text-3xl font-medium text-[#0A7334] mt-3 tracking-[-0.02em]">{approvedCount}</p>
          <p className="text-[11px] text-[#0A7334] mt-1">Active on police GIS map</p>
        </div>

        <div className="mc-card p-4 sm:p-5 flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-[#B56708]">Pending Review</span>
            <div className="w-8 h-8 rounded-full bg-[#FEF6E9] text-[#B56708] flex items-center justify-center shrink-0">
              <Clock className="w-4 h-4" />
            </div>
          </div>
          <p className="text-2xl sm:text-3xl font-medium text-[#B56708] mt-3 tracking-[-0.02em]">{pendingCount}</p>
          <p className="text-[11px] text-[#B56708] mt-1">Awaiting police review</p>
        </div>

        <div className="mc-card p-4 sm:p-5 flex flex-col justify-between">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-[#CF4500]">Rejected</span>
            <div className="w-8 h-8 rounded-full bg-[#FDF0EE] text-[#CF4500] flex items-center justify-center shrink-0">
              <XCircle className="w-4 h-4" />
            </div>
          </div>
          <p className="text-2xl sm:text-3xl font-medium text-[#CF4500] mt-3 tracking-[-0.02em]">{rejectedCount}</p>
          <p className="text-[11px] text-[#CF4500] mt-1">Correction required</p>
        </div>
      </div>

      {/* Surveyed Cameras Grid Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
        {isLoading ? (
          <div className="col-span-full mc-stadium p-12 text-center text-[#696969]">
            Loading your surveyed cameras...
          </div>
        ) : displayList.length === 0 ? (
          <div className="col-span-full mc-stadium p-12 text-center text-[#696969] space-y-2">
            <ClipboardList className="w-12 h-12 text-[#696969] mx-auto opacity-50" />
            <h3 className="text-lg font-medium text-[#141413]">No Field Surveys Recorded Yet</h3>
            <p className="text-xs text-[#696969]">Click 'Survey New Camera' above to register your first CCTV point.</p>
          </div>
        ) : (
          displayList.map((cam, idx) => (
            <motion.div 
              key={cam.id || cam.cameraCode} 
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: idx * 0.03 }}
              className="mc-card p-5 sm:p-6 flex flex-col justify-between hover:border-[#D1CDC7] hover:shadow-mc-elevated transition-all duration-200"
            >
              <div className="space-y-3.5">
                <div className="flex items-center justify-between border-b border-[#E5DFD9] pb-3">
                  <span className="font-mono font-bold text-[#141413] text-sm">{cam.cameraCode}</span>
                  <span className="text-[10px] bg-[#F3F0EE] text-[#141413] border border-[#D1CDC7] px-2.5 py-0.5 rounded-full font-mono font-medium">
                    {cam.cameraType}
                  </span>
                </div>

                <div>
                  <div className="mc-eyebrow text-[10px] mb-1">
                    <span className="mc-eyebrow-dot"></span>
                    <span>SURVEY RECORD</span>
                  </div>
                  <h4 className="font-medium text-[#141413] text-base leading-snug">{cam.cameraName}</h4>
                </div>

                <div className="text-xs text-[#696969] space-y-1">
                  <p className="flex items-center gap-1.5">
                    <MapPin className="w-3.5 h-3.5 text-[#CF4500] shrink-0" />
                    <span className="truncate">{cam.fullAddress || cam.area}</span>
                  </p>
                  <p className="font-mono text-[11px] text-[#696969]">
                    Coords: {cam.latitude?.toFixed(5)}, {cam.longitude?.toFixed(5)}
                  </p>
                </div>

                {/* Status Badges */}
                <div className="flex items-center justify-between pt-1">
                  <span className={cam.cameraStatus === 'ACTIVE' ? 'badge-active' : 'badge-offline'}>
                    {cam.cameraStatus === 'ACTIVE' ? '● Online' : '● Offline'}
                  </span>
                  <span className={
                    cam.verificationStatus === 'APPROVED' 
                      ? 'badge-approved' 
                      : cam.verificationStatus === 'REJECTED' 
                      ? 'badge-rejected' 
                      : 'badge-pending'
                  }>
                    {cam.verificationStatus === 'APPROVED' 
                      ? '✓ Approved' 
                      : cam.verificationStatus === 'REJECTED' 
                      ? '× Rejected' 
                      : '◷ Pending'}
                  </span>
                </div>

                {/* Rejection Alert if Rejected */}
                {cam.verificationStatus === 'REJECTED' && cam.rejectionReason && (
                  <div className="p-3 rounded-[16px] bg-[#FDF0EE] border border-[#F8C6BC] text-[#CF4500] text-xs space-y-1">
                    <span className="font-bold flex items-center gap-1">
                      <AlertTriangle className="w-3.5 h-3.5 text-[#CF4500]" />
                      Rejection Reason:
                    </span>
                    <p className="text-[11px]">{cam.rejectionReason}</p>
                  </div>
                )}

                {/* Technical Specs */}
                <div className="grid grid-cols-2 gap-2 text-[11px] bg-[#F3F0EE] p-3 rounded-[18px] text-[#141413]">
                  <div>
                    <span className="text-[#696969] block text-[9px] uppercase font-semibold">Direction</span>
                    <strong className="text-[#3860BE] mt-0.5 block">{cam.directionAngle || 0}° ({cam.cardinalDirection || 'EAST'})</strong>
                  </div>
                  <div>
                    <span className="text-[#696969] block text-[9px] uppercase font-semibold">Coverage Arc</span>
                    <strong className="text-[#141413] mt-0.5 block">{cam.coverageRadiusMeters || 80}m</strong>
                  </div>
                </div>
              </div>

              <div className="pt-4 mt-4 border-t border-[#E5DFD9] flex justify-end">
                <button
                  onClick={() => setViewingCamera(cam)}
                  className="mc-btn-secondary text-xs py-1.5 px-3"
                >
                  <Eye className="w-3.5 h-3.5 text-[#3860BE]" />
                  <span>Inspect Details</span>
                </button>
              </div>
            </motion.div>
          ))
        )}
      </div>

      {/* Inspect Camera Modal */}
      {viewingCamera && (
        <div className="fixed inset-0 bg-[#141413]/60 backdrop-blur-xs z-50 flex items-end sm:items-center justify-center p-0 sm:p-4">
          <motion.div 
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="mc-stadium w-full sm:max-w-md rounded-b-none sm:rounded-[40px] p-6 md:p-8 space-y-5 relative shadow-2xl bg-[#FCFBFA]"
          >
            <button
              onClick={() => setViewingCamera(null)}
              className="absolute top-5 right-5 p-2 rounded-full text-[#696969] hover:text-[#141413] hover:bg-[#F3F0EE]"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="flex items-center gap-3.5 border-b border-[#E5DFD9] pb-4">
              <div className="w-12 h-12 rounded-full bg-[#141413] text-[#FCFBFA] flex items-center justify-center font-bold">
                <Camera className="w-6 h-6" />
              </div>
              <div className="pr-6">
                <div className="mc-eyebrow text-[10px]">
                  <span className="mc-eyebrow-dot"></span>
                  <span>SURVEYED POINT</span>
                </div>
                <h3 className="font-medium text-[#141413] text-base leading-snug">{viewingCamera.cameraName}</h3>
                <p className="font-mono text-xs text-[#3860BE]">{viewingCamera.cameraCode}</p>
              </div>
            </div>

            {/* On-site photo preview if available */}
            {viewingCamera.imageUrl && (
              <div className="rounded-[20px] overflow-hidden border border-[#E5DFD9] h-40 bg-black">
                <img 
                  src={viewingCamera.imageUrl} 
                  alt={viewingCamera.cameraName} 
                  className="w-full h-full object-cover"
                />
              </div>
            )}

            <div className="grid grid-cols-2 gap-2.5 text-xs text-[#141413]">
              <div className="bg-white p-3 rounded-[18px] border border-[#E5DFD9]">
                <span className="text-[#696969] text-[10px] uppercase font-semibold block">Status</span>
                <span className={`mt-1 inline-block ${viewingCamera.verificationStatus === 'APPROVED' ? 'badge-approved' : 'badge-pending'}`}>
                  {viewingCamera.verificationStatus}
                </span>
              </div>
              <div className="bg-white p-3 rounded-[18px] border border-[#E5DFD9]">
                <span className="text-[#696969] text-[10px] uppercase font-semibold block">Coverage</span>
                <strong className="text-[#141413] mt-1 block">{viewingCamera.coverageRadiusMeters}m</strong>
              </div>
            </div>


          </motion.div>
        </div>
      )}

      {/* Surveyor Registration Modal with Owner Mobile Verification & Photo Capture */}
      <SurveyRegistrationModal 
        isOpen={showAddModal} 
        onClose={() => setShowAddModal(false)} 
      />
    </div>
  );
};
