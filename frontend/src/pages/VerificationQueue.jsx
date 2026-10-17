import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import api from '../api/axios';
import { 
  CheckCircle2, 
  XCircle, 
  Clock, 
  MapPin, 
  Camera, 
  User, 
  Phone, 
  Compass, 
  AlertTriangle, 
  Check, 
  X, 
  ShieldCheck,
  Shield,
  ArrowRight
} from 'lucide-react';
import { motion } from 'framer-motion';

export const VerificationQueue = () => {
  const queryClient = useQueryClient();
  const [rejectModalId, setRejectModalId] = useState(null);
  const [rejectionReason, setRejectionReason] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['pending-cameras'],
    queryFn: () => api.get('/cameras/search?verificationStatus=PENDING&size=100'),
    refetchInterval: 3000,
  });

  const approvalMutation = useMutation({
    mutationFn: ({ id, verificationStatus, rejectionReason }) =>
      api.patch(`/cameras/${id}/approval`, { verificationStatus, rejectionReason }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pending-cameras'] });
      queryClient.invalidateQueries({ queryKey: ['cameras'] });
      queryClient.invalidateQueries({ queryKey: ['nearby-cameras-all'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard-stats'] });
      setRejectModalId(null);
      setRejectionReason('');
    },
  });

  const handleApprove = (id) => {
    approvalMutation.mutate({ id, verificationStatus: 'APPROVED' });
  };

  const handleRejectSubmit = (e) => {
    e.preventDefault();
    if (!rejectModalId) return;
    approvalMutation.mutate({
      id: rejectModalId,
      verificationStatus: 'REJECTED',
      rejectionReason,
    });
  };

  const pendingCameras = data?.data?.content || [];

  return (
    <div className="space-y-6 md:space-y-8">
      {/* Top Banner */}
      <div className="mc-stadium p-5 sm:p-7 md:p-8 flex flex-col md:flex-row md:items-center justify-between gap-5 relative overflow-hidden">
        <div className="absolute right-0 top-1/2 -translate-y-1/2 text-[100px] md:text-[140px] font-bold text-[#E8E2DA]/40 select-none pointer-events-none tracking-[-0.04em] pr-4">
          VERIFY
        </div>

        <div className="relative z-10 max-w-2xl space-y-2">
          <div className="mc-eyebrow">
            <span className="mc-eyebrow-dot"></span>
            <span>POLICE GIS AUTHORIZATION GATEWAY</span>
          </div>

          <h1 className="text-2xl sm:text-3xl md:text-4xl font-medium text-[#141413] tracking-[-0.02em] leading-tight">
            Field Survey Verification Queue
          </h1>

          <p className="text-sm md:text-base text-[#696969] font-normal leading-relaxed">
            Review and authorize newly surveyed CCTV cameras into the live police investigation GIS network.
          </p>
        </div>

        <div className="relative z-10 flex items-center gap-2.5 px-4 py-2 rounded-full bg-white border border-[#D1CDC7] shadow-xs shrink-0 self-start md:self-auto">
          <span className="w-2.5 h-2.5 rounded-full bg-[#CF4500] animate-pulse"></span>
          <span className="font-mono font-bold text-xs text-[#141413]">
            {pendingCameras.length} PENDING VERIFICATION
          </span>
        </div>
      </div>

      {/* Grid of Pending Camera Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
        {isLoading ? (
          <div className="col-span-full mc-stadium p-12 text-center text-[#696969]">
            <div className="animate-pulse space-y-3 max-w-sm mx-auto">
              <div className="h-5 bg-[#E5DFD9] rounded-full w-2/3 mx-auto"></div>
              <div className="h-4 bg-[#E5DFD9] rounded-full w-1/2 mx-auto"></div>
            </div>
          </div>
        ) : pendingCameras.length === 0 ? (
          <div className="col-span-full mc-stadium p-12 sm:p-16 text-center space-y-4">
            <div className="w-16 h-16 rounded-full bg-[#EAF7EE] text-[#0A7334] border border-[#BDE7CA] flex items-center justify-center mx-auto shadow-xs">
              <CheckCircle2 className="w-8 h-8" />
            </div>
            <div>
              <h3 className="text-xl font-medium text-[#141413] tracking-[-0.02em]">Verification Queue Clear</h3>
              <p className="text-xs sm:text-sm text-[#696969] mt-1.5 max-w-md mx-auto">
                All surveyed CCTV cameras have been authorized and merged into the active police GIS radar.
              </p>
            </div>
          </div>
        ) : (
          pendingCameras.map((cam, idx) => (
            <motion.div 
              key={cam.id}
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: idx * 0.03 }}
              className="mc-card p-5 sm:p-6 flex flex-col justify-between hover:border-[#D1CDC7] hover:shadow-mc-elevated transition-all duration-200"
            >
              <div className="space-y-4">
                <div className="flex items-center justify-between border-b border-[#E5DFD9] pb-3">
                  <span className="font-mono font-bold text-[#141413] text-sm">{cam.cameraCode}</span>
                  <span className="text-[10px] bg-[#F3F0EE] text-[#141413] border border-[#D1CDC7] px-2.5 py-0.5 rounded-full font-mono font-medium">
                    {cam.cameraType}
                  </span>
                </div>

                <div>
                  <div className="mc-eyebrow text-[10px] mb-1">
                    <span className="mc-eyebrow-dot"></span>
                    <span>SURVEY SUBMISSION</span>
                  </div>
                  <h4 className="font-medium text-[#141413] text-base leading-snug">{cam.cameraName}</h4>
                </div>

                <div className="text-xs text-[#696969] space-y-1">
                  <p className="flex items-center gap-1.5">
                    <MapPin className="w-3.5 h-3.5 text-[#CF4500] shrink-0" />
                    <span className="truncate">{cam.fullAddress || cam.area || 'Zone 1'}</span>
                  </p>
                  <p className="font-mono text-[11px] text-[#696969]">
                    GPS: {cam.latitude?.toFixed(5)}, {cam.longitude?.toFixed(5)}
                  </p>
                </div>

                {/* Camera Owner Specs Card */}
                <div className="p-3.5 rounded-[20px] bg-[#F3F0EE] border border-[#E5DFD9] text-xs space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="font-medium text-[#141413] flex items-center gap-1.5">
                      <User className="w-3.5 h-3.5 text-[#3860BE]" />
                      {cam.ownerName || 'Govt / Police Dept'}
                    </span>
                    <span className="text-[9px] bg-white text-[#141413] px-2 py-0.5 rounded-full uppercase font-mono border border-[#D1CDC7]">
                      {cam.ownerType || 'COMMERCIAL'}
                    </span>
                  </div>

                  {cam.ownerContact && (
                    <p className="text-[11px] text-[#696969] flex items-center gap-1.5 font-mono">
                      <Phone className="w-3.5 h-3.5 text-[#696969]" />
                      Phone: <a href={`tel:${cam.ownerContact}`} className="text-[#3860BE] font-medium hover:underline">{cam.ownerContact}</a>
                    </p>
                  )}
                </div>

                {/* Technical Specs */}
                <div className="grid grid-cols-2 gap-2 text-[11px] bg-white p-3 rounded-[20px] border border-[#E5DFD9] text-[#141413]">
                  <div>
                    <span className="text-[#696969] block text-[9px] uppercase font-semibold">Direction</span>
                    <strong className="flex items-center gap-1 text-[#3860BE] mt-0.5">
                      <Compass className="w-3 h-3" /> {cam.directionAngle || 0}° ({cam.cardinalDirection})
                    </strong>
                  </div>
                  <div>
                    <span className="text-[#696969] block text-[9px] uppercase font-semibold">Coverage Arc</span>
                    <strong className="text-[#141413] mt-0.5 block">{cam.coverageRadiusMeters || 80}m</strong>
                  </div>
                  <div className="col-span-2 pt-2 border-t border-[#E5DFD9] text-[#696969] text-[10px]">
                    Field Surveyor: <strong className="text-[#141413]">{cam.surveyorName || 'Field Team'}</strong>
                  </div>
                </div>
              </div>

              {/* Action Buttons: Ink Black primary approve & Signal Orange reject */}
              <div className="pt-4 mt-4 border-t border-[#E5DFD9] flex items-center gap-2.5">
                <button
                  onClick={() => handleApprove(cam.id)}
                  disabled={approvalMutation.isPending}
                  className="flex-1 mc-btn-primary text-xs py-2"
                >
                  <Check className="w-3.5 h-3.5" />
                  <span>Authorize</span>
                </button>

                <button
                  onClick={() => setRejectModalId(cam.id)}
                  disabled={approvalMutation.isPending}
                  className="flex-1 mc-btn-signal text-xs py-2"
                >
                  <X className="w-3.5 h-3.5" />
                  <span>Reject</span>
                </button>
              </div>
            </motion.div>
          ))
        )}
      </div>

      {/* Reject Modal */}
      {rejectModalId && (
        <div className="fixed inset-0 bg-[#141413]/60 backdrop-blur-xs z-50 flex items-end sm:items-center justify-center p-0 sm:p-4">
          <motion.div 
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            className="mc-stadium w-full sm:max-w-md rounded-b-none sm:rounded-[40px] p-6 md:p-8 space-y-5 shadow-2xl bg-[#FCFBFA]"
          >
            <div className="flex items-center justify-between border-b border-[#E5DFD9] pb-3">
              <div>
                <div className="mc-eyebrow text-[10px]">
                  <span className="mc-eyebrow-dot"></span>
                  <span>VERIFICATION REJECTION</span>
                </div>
                <h3 className="text-lg font-medium text-[#141413] tracking-[-0.02em]">Specify Rejection Reason</h3>
              </div>
              <button onClick={() => setRejectModalId(null)} className="p-2 rounded-full text-[#696969] hover:text-[#141413] hover:bg-[#F3F0EE]">
                <X className="w-5 h-5" />
              </button>
            </div>
            
            <form onSubmit={handleRejectSubmit} className="space-y-4 text-xs">
              <div>
                <label className="block text-[#141413] font-medium mb-1.5">
                  Reason for Rejection <span className="text-[#CF4500]">*</span>
                </label>
                <textarea
                  required
                  rows="3"
                  value={rejectionReason}
                  onChange={(e) => setRejectionReason(e.target.value)}
                  placeholder="e.g. Obstructed field of view, incorrect GPS coordinates, invalid owner phone"
                  className="mc-input w-full rounded-[18px] p-3 text-xs"
                ></textarea>
              </div>

              <div className="flex justify-end gap-2.5 pt-4 border-t border-[#E5DFD9]">
                <button
                  type="button"
                  onClick={() => setRejectModalId(null)}
                  className="mc-btn-secondary py-2"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={approvalMutation.isPending}
                  className="mc-btn-signal py-2"
                >
                  Confirm Rejection
                </button>
              </div>
            </form>
          </motion.div>
        </div>
      )}
    </div>
  );
};
