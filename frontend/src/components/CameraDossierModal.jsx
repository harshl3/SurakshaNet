import React, { useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Camera, ShieldCheck, Lock, X, MapPin, ExternalLink } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export const CameraDossierModal = ({ camera, onClose, isSurveyor: isSurveyorProp }) => {
  const { user } = useAuth();
  const userRole = typeof user?.role === 'object' ? user?.role?.name : user?.role;
  const isSurveyor = isSurveyorProp !== undefined ? isSurveyorProp : userRole === 'ROLE_SURVEY_PERSON';

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Escape' && camera && onClose) {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [camera, onClose]);

  if (!camera) return null;

  return (
    <AnimatePresence>
      <div 
        className="fixed inset-0 bg-[#141413]/60 backdrop-blur-xs z-[99999] flex items-end sm:items-center justify-center p-0 sm:p-4"
        onClick={(e) => {
          if (e.target === e.currentTarget && onClose) onClose();
        }}
      >
        <motion.div 
          initial={{ opacity: 0, scale: 0.95, y: 16 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 16 }}
          transition={{ duration: 0.18, ease: 'easeOut' }}
          className="mc-stadium w-full sm:max-w-lg rounded-b-none sm:rounded-[40px] max-h-[90vh] overflow-y-auto p-6 md:p-8 space-y-5 relative shadow-2xl bg-[#FCFBFA] border border-[#E5DFD9]"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Close Button */}
          <button
            type="button"
            onClick={onClose}
            className="absolute top-5 right-5 p-2 rounded-full text-[#696969] hover:text-[#141413] hover:bg-[#F3F0EE] transition-colors cursor-pointer"
            aria-label="Close dossier"
          >
            <X className="w-5 h-5" />
          </button>

          {/* Header with Camera Icon, Code and Name */}
          <div className="flex items-center gap-3.5 border-b border-[#E5DFD9] pb-4">
            <div className="w-12 h-12 rounded-full bg-[#141413] text-[#FCFBFA] flex items-center justify-center font-bold shrink-0">
              <Camera className="w-6 h-6" />
            </div>
            <div className="pr-6">
              <div className="mc-eyebrow text-[10px]">
                <span className="mc-eyebrow-dot"></span>
                <span>CCTV NODE DOSSIER</span>
              </div>
              <h3 className="font-medium text-[#141413] text-lg leading-snug">{camera.cameraName || 'Surveillance Node'}</h3>
              <p className="font-mono text-xs text-[#3860BE]">{camera.cameraCode || 'CCTV-NODE'}</p>
              {(camera.fullAddress || camera.area) && (
                <p className="text-[11px] text-[#696969] mt-0.5 flex items-center gap-1">
                  <MapPin className="w-3 h-3 text-[#CF4500] shrink-0" />
                  <span className="line-clamp-1">{camera.fullAddress || camera.area}</span>
                </p>
              )}
            </div>
          </div>

          {/* Camera Visual Capture (Supabase / Local Cloud Media) */}
          {camera.imageUrl && (
            <div className="relative rounded-[24px] overflow-hidden border border-[#E5DFD9] bg-[#141413] shadow-inner group">
              <img 
                src={camera.imageUrl} 
                alt={camera.cameraName || 'CCTV Installation Site'} 
                className="w-full h-44 sm:h-52 object-cover transition-transform duration-300 group-hover:scale-105"
                onError={(e) => {
                  e.currentTarget.style.display = 'none';
                }}
              />
              <div className="absolute top-3 left-3 bg-[#141413]/85 backdrop-blur-md px-2.5 py-1 rounded-full border border-white/15 text-white text-[10px] font-semibold flex items-center gap-1.5 shadow-md">
                <Camera className="w-3 h-3 text-[#10B981]" />
                <span>SURVEILLANCE CAPTURE</span>
              </div>
              <a 
                href={camera.imageUrl} 
                target="_blank" 
                rel="noopener noreferrer"
                className="absolute bottom-3 right-3 bg-white/90 hover:bg-white backdrop-blur-md px-2.5 py-1 rounded-full text-[#141413] text-[11px] font-semibold flex items-center gap-1 shadow-md transition-all hover:scale-105"
                title="View Full Resolution Image"
              >
                <span>Full View</span>
                <ExternalLink className="w-3 h-3" />
              </a>
            </div>
          )}

          {/* Camera Owner Details Card */}
          {isSurveyor ? (
            <div className="bg-[#FEF6E9] p-3.5 rounded-[20px] border border-[#FADBA6] text-[#B56708] text-xs flex items-center gap-2 font-medium">
              <Lock className="w-4 h-4 text-[#B56708] shrink-0" />
              <span>Sensitive Camera Owner Info Restricted (Police Officer Access Only)</span>
            </div>
          ) : (
            <div className="bg-[#F3F0EE] p-4 rounded-[24px] border border-[#E5DFD9] space-y-2 text-xs">
              <p className="font-bold text-[#141413] flex items-center gap-1.5 text-xs uppercase tracking-wider">
                <ShieldCheck className="w-4 h-4 text-[#3860BE]" />
                Registered Camera Owner Details
              </p>
              <div className="grid grid-cols-2 gap-3 text-[#141413] pt-1">
                <div>
                  <p className="text-[#696969] text-[10px] uppercase font-semibold">Owner / Shop</p>
                  <p className="font-medium text-[#141413]">{camera.ownerName || 'Govt / Police Dept'}</p>
                </div>
                <div>
                  <p className="text-[#696969] text-[10px] uppercase font-semibold">Phone Contact</p>
                  <p className="font-mono font-medium text-[#141413]">{camera.ownerContact || 'N/A'}</p>
                </div>
                <div>
                  <p className="text-[#696969] text-[10px] uppercase font-semibold">Ownership Type</p>
                  <p className="font-medium text-[#3860BE] uppercase">{camera.ownerType || 'COMMERCIAL'}</p>
                </div>
                <div>
                  <p className="text-[#696969] text-[10px] uppercase font-semibold">Field Surveyor</p>
                  <p className="font-medium text-[#141413]">{camera.surveyorName || 'Field Team'}</p>
                </div>
              </div>
            </div>
          )}

          {/* Technical Hardware Specs (2x2 Grid) */}
          <div className="grid grid-cols-2 gap-2.5 text-xs text-[#141413]">
            <div className="bg-white p-3 rounded-[20px] border border-[#E5DFD9]">
              <p className="text-[#696969] text-[10px] uppercase font-semibold">Type &amp; Status</p>
              <p className="font-medium text-[#141413] flex items-center justify-between mt-1">
                <span>{camera.cameraType || 'FIXED'}</span>
                <span className={camera.cameraStatus === 'ACTIVE' ? 'badge-active' : 'badge-offline'}>
                  {camera.cameraStatus || 'ACTIVE'}
                </span>
              </p>
            </div>
            <div className="bg-white p-3 rounded-[20px] border border-[#E5DFD9]">
              <p className="text-[#696969] text-[10px] uppercase font-semibold">Coverage Radius</p>
              <p className="font-medium text-[#141413] mt-1">{camera.coverageRadiusMeters || 80} meters</p>
            </div>
            <div className="bg-white p-3 rounded-[20px] border border-[#E5DFD9]">
              <p className="text-[#696969] text-[10px] uppercase font-semibold">Lens Direction</p>
              <p className="font-medium text-[#3860BE] mt-1">
                {camera.cardinalDirection || 'EAST'} ({camera.directionAngle || 0}°)
              </p>
            </div>
            <div className="bg-white p-3 rounded-[20px] border border-[#E5DFD9]">
              <p className="text-[#696969] text-[10px] uppercase font-semibold">FOV Spread</p>
              <p className="font-medium text-[#CF4500] mt-1">{camera.fovAngle || 60}° Angle</p>
            </div>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
};
