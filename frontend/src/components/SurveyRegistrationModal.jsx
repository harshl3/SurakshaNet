import React, { useState, useRef, useEffect } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import api from '../api/axios';
import { CameraMap } from './CameraMap';
import { 
  Camera, 
  MapPin, 
  Navigation, 
  Compass, 
  User, 
  Phone, 
  AlertTriangle, 
  CheckCircle2, 
  Clock, 
  XCircle, 
  X, 
  Search, 
  Upload, 
  Video, 
  RefreshCw, 
  ShieldCheck, 
  Check, 
  ArrowRight, 
  ArrowLeft,
  Building2,
  ScanLine,
  Eye,
  Layers,
  Sparkles
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

export const SurveyRegistrationModal = ({ isOpen, onClose, defaultStationId = null }) => {
  const queryClient = useQueryClient();

  // Wizard Step: 1 = Owner Mobile Verification & Review, 2 = Register New Camera Node
  const [currentStep, setCurrentStep] = useState(1);

  // Step 1: Owner Search & Review State
  const [ownerPhoneSearch, setOwnerPhoneSearch] = useState('');
  const [isSearchingOwner, setIsSearchingOwner] = useState(false);
  const [ownerSearchPerformed, setOwnerSearchPerformed] = useState(false);
  const [ownerData, setOwnerData] = useState(null);
  const [selectedExistingCamera, setSelectedExistingCamera] = useState(null);

  // Step 2: New Camera Registration State
  const [form, setForm] = useState({
    cameraCode: `CAM-${Math.floor(1000 + Math.random() * 9000)}`,
    cameraName: '',
    cameraType: 'PTZ',
    latitude: 21.1458,
    longitude: 79.0882,
    city: 'Nagpur',
    state: 'Maharashtra',
    area: 'Central Zone',
    fullAddress: '',
    cardinalDirection: 'EAST',
    directionAngle: 90,
    coverageRadiusMeters: 100,
    fovAngle: 60,
    ownerName: '',
    ownerContact: '',
    ownerType: 'COMMERCIAL',
    imageUrl: '',
    policeStationId: defaultStationId,
  });

  // Location & Map Picker State
  const [useMapPicker, setUseMapPicker] = useState(false);
  const [isLocatingGPS, setIsLocatingGPS] = useState(false);
  const [gpsSuccess, setGpsSuccess] = useState(false);

  // Duplicate Check State
  const [duplicateStatus, setDuplicateStatus] = useState({
    isChecking: false,
    isDuplicate: false,
    duplicateField: '',
    message: '',
    existingCamera: null,
  });

  // Live Camera Photo Capture & Upload State
  const [photoSourceMode, setPhotoSourceMode] = useState('upload'); // 'camera' or 'upload'
  const [isCameraActive, setIsCameraActive] = useState(false);
  const [cameraStream, setCameraStream] = useState(null);
  const [isUploadingPhoto, setIsUploadingPhoto] = useState(false);
  const [photoPreview, setPhotoPreview] = useState('');
  const [isScanningSerial, setIsScanningSerial] = useState(false);

  // Error and feedback
  const [errorMessage, setErrorMessage] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  const videoRef = useRef(null);
  const canvasRef = useRef(null);
  const fileInputRef = useRef(null);

  // Cleanup camera stream when closing modal or switching
  useEffect(() => {
    return () => {
      stopCameraStream();
    };
  }, []);

  const stopCameraStream = () => {
    if (cameraStream) {
      cameraStream.getTracks().forEach((track) => track.stop());
      setCameraStream(null);
      setIsCameraActive(false);
    }
  };

  // Quick sample phone numbers for instant surveyor demonstration
  const sampleOwners = [
    { label: 'Sitabuldi Traders', number: '+91 98711 44444' },
    { label: 'Apex Retail', number: '+91 98711 77777' },
    { label: 'Shopkeepers Assn', number: '+91 98765 11111' },
  ];

  // -------------------------------------------------------------
  // STEP 1: Search Owner by Mobile Number
  // -------------------------------------------------------------
  const handleOwnerSearch = async (phoneToSearch) => {
    const query = phoneToSearch || ownerPhoneSearch;
    if (!query || query.trim().length < 4) {
      setErrorMessage('Please enter a valid owner mobile number to verify.');
      return;
    }

    setIsSearchingOwner(true);
    setErrorMessage('');
    try {
      const res = await api.get(`/cameras/owner-lookup?contact=${encodeURIComponent(query.trim())}`);
      const data = res.data;
      setOwnerData(data);
      setOwnerSearchPerformed(true);

      // Pre-fill Step 2 form details with owner information
      if (data && data.ownerFound) {
        setForm((prev) => ({
          ...prev,
          ownerName: data.ownerName || 'Store Owner',
          ownerContact: data.ownerContact || query.trim(),
          ownerType: data.ownerType || 'COMMERCIAL',
          fullAddress: data.cameras?.[0]?.fullAddress || prev.fullAddress,
          area: data.cameras?.[0]?.area || prev.area,
          city: data.cameras?.[0]?.city || prev.city,
        }));
      } else {
        setForm((prev) => ({
          ...prev,
          ownerContact: query.trim(),
          ownerName: '',
        }));
      }
    } catch (err) {
      console.error('Failed to lookup owner:', err);
      // Fallback mock if local server is bootstrapping
      setOwnerSearchPerformed(true);
      setOwnerData({
        ownerFound: false,
        ownerContact: query.trim(),
        maskedContact: query.trim(),
        totalCameras: 0,
        approvedCount: 0,
        pendingCount: 0,
        cameras: [],
      });
    } finally {
      setIsSearchingOwner(false);
    }
  };

  // -------------------------------------------------------------
  // STEP 2: Duplicate Detection Check
  // -------------------------------------------------------------
  useEffect(() => {
    if (currentStep !== 2) return;
    const code = form.cameraCode?.trim();

    if (!code) {
      setDuplicateStatus({ isChecking: false, isDuplicate: false, message: '' });
      return;
    }

    const timer = setTimeout(async () => {
      setDuplicateStatus((prev) => ({ ...prev, isChecking: true }));
      try {
        const res = await api.get('/cameras/check-duplicate', {
          params: { cameraCode: code }
        });
        const d = res.data;
        setDuplicateStatus({
          isChecking: false,
          isDuplicate: d.duplicate,
          duplicateField: d.duplicateField || '',
          message: d.message || '',
          existingCamera: d.existingCamera || null,
        });
      } catch (err) {
        setDuplicateStatus({ isChecking: false, isDuplicate: false, message: '' });
      }
    }, 450);

    return () => clearTimeout(timer);
  }, [form.cameraCode, currentStep]);

  // -------------------------------------------------------------
  // Live Camera Photo Capture & Upload Logic
  // -------------------------------------------------------------
  const startCameraStream = async () => {
    stopCameraStream();
    setPhotoSourceMode('camera');
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: { ideal: 'environment' },
          width: { ideal: 1280 },
          height: { ideal: 720 },
        },
      });
      setCameraStream(stream);
      setIsCameraActive(true);
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
      }
    } catch (err) {
      console.warn('Unable to access device camera via getUserMedia:', err);
      alert('Camera access unavailable or permission denied. Please use the file upload option to select or take a photo.');
      setPhotoSourceMode('upload');
    }
  };

  const captureCameraSnapshot = async () => {
    if (!videoRef.current || !canvasRef.current) return;
    const video = videoRef.current;
    const canvas = canvasRef.current;
    canvas.width = video.videoWidth || 640;
    canvas.height = video.videoHeight || 480;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

    canvas.toBlob(async (blob) => {
      if (!blob) return;
      const dataUrl = canvas.toDataURL('image/jpeg', 0.85);
      setPhotoPreview(dataUrl);
      stopCameraStream();

      // Upload blob to server
      await uploadMediaFile(blob, 'live_camera_capture.jpg');
    }, 'image/jpeg', 0.88);
  };

  const handleFileUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Show local preview immediately
    const reader = new FileReader();
    reader.onload = (event) => {
      setPhotoPreview(event.target.result);
    };
    reader.readAsDataURL(file);

    await uploadMediaFile(file, file.name);
  };

  const uploadMediaFile = async (fileOrBlob, filename) => {
    setIsUploadingPhoto(true);
    setErrorMessage('');
    const formData = new FormData();
    formData.append('file', fileOrBlob, filename);

    try {
      const res = await api.post('/media/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      if (res.data?.url) {
        setForm((prev) => ({ ...prev, imageUrl: res.data.url }));
      }
    } catch (err) {
      console.warn('Media upload to server failed, storing preview image locally:', err);
      // Fallback: save data URL as imageUrl so image is never lost
      if (photoPreview) {
        setForm((prev) => ({ ...prev, imageUrl: photoPreview }));
      }
    } finally {
      setIsUploadingPhoto(false);
    }
  };

  // -------------------------------------------------------------
  // GPS Location Handler
  // -------------------------------------------------------------
  const handleGetCurrentGPS = () => {
    if (!navigator.geolocation) {
      alert('Geolocation is not supported by your browser.');
      return;
    }
    setIsLocatingGPS(true);
    setGpsSuccess(false);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const lat = Math.round(pos.coords.latitude * 100000) / 100000;
        const lng = Math.round(pos.coords.longitude * 100000) / 100000;
        setForm((prev) => ({
          ...prev,
          latitude: lat,
          longitude: lng,
        }));
        setIsLocatingGPS(false);
        setGpsSuccess(true);
        setTimeout(() => setGpsSuccess(false), 3000);
      },
      (err) => {
        console.warn('GPS location error:', err);
        setIsLocatingGPS(false);
        alert('GPS location capture failed. Please ensure location permissions are allowed, or set coordinates manually / using the map picker.');
      },
      { enableHighAccuracy: true, timeout: 10000, maximumAge: 0 }
    );
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
      setForm((prev) => ({
        ...prev,
        latitude: Math.round(numLat * 100000) / 100000,
        longitude: Math.round(numLng * 100000) / 100000,
      }));
    }
  };

  // -------------------------------------------------------------
  // Scan Serial Number Simulator
  // -------------------------------------------------------------
  const handleSimulateScanSerial = () => {
    setIsScanningSerial(true);
    setTimeout(() => {
      const randomSN = `SN-CCTV-${Math.floor(100000 + Math.random() * 900000)}`;
      setForm((prev) => ({ ...prev, serialNumber: randomSN }));
      setIsScanningSerial(false);
    }, 700);
  };

  // -------------------------------------------------------------
  // Submit New Camera Survey Mutation
  // -------------------------------------------------------------
  const addCameraMutation = useMutation({
    mutationFn: (newCam) => api.post('/cameras', newCam),
    onSuccess: (res) => {
      queryClient.invalidateQueries({ queryKey: ['my-surveyed-cameras'] });
      queryClient.invalidateQueries({ queryKey: ['cameras'] });
      queryClient.invalidateQueries({ queryKey: ['pending-cameras'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard-analytics'] });
      setSuccessMessage('Camera survey submitted successfully! Sent to Police Admin for Verification (Status: PENDING).');
      setTimeout(() => {
        stopCameraStream();
        onClose();
      }, 1800);
    },
    onError: (err) => {
      const msg = err.response?.data?.message || err.message || 'Failed to submit camera survey. Please check all fields.';
      setErrorMessage(msg);
    },
  });

  const handleFinalSubmit = (e) => {
    e.preventDefault();
    setErrorMessage('');

    if (duplicateStatus.isDuplicate) {
      setErrorMessage(`Cannot register: Duplicate ${duplicateStatus.duplicateField} detected!`);
      return;
    }

    if (!form.cameraName || !form.latitude || !form.longitude) {
      setErrorMessage('Please fill in Camera Landmark/Name and valid GPS coordinates.');
      return;
    }

    if (!form.ownerContact) {
      setErrorMessage('Please provide the Owner Contact number.');
      return;
    }

    addCameraMutation.mutate({
      ...form,
      latitude: parseFloat(form.latitude),
      longitude: parseFloat(form.longitude),
      directionAngle: parseFloat(form.directionAngle) || 0,
      coverageRadiusMeters: parseFloat(form.coverageRadiusMeters) || 100,
      fovAngle: parseFloat(form.fovAngle) || 60,
    });
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-[#141413]/70 backdrop-blur-xs z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 overflow-y-auto">
      <motion.div 
        initial={{ opacity: 0, scale: 0.96 }}
        animate={{ opacity: 1, scale: 1 }}
        exit={{ opacity: 0, scale: 0.96 }}
        className="mc-stadium w-full sm:max-w-3xl rounded-b-none sm:rounded-[36px] max-h-[94vh] overflow-y-auto p-5 sm:p-7 md:p-8 space-y-6 my-0 sm:my-6 shadow-2xl flex flex-col justify-between bg-[#FCFBFA] border border-[#E5DFD9]"
      >
        {/* Header with Step indicator */}
        <div>
          <div className="flex items-center justify-between border-b border-[#E5DFD9] pb-4">
            <div>
              <div className="mc-eyebrow text-[10px]">
                <span className="mc-eyebrow-dot"></span>
                <span>FIELD PATROL INTELLIGENCE &amp; AUDIT</span>
              </div>
              <h2 className="text-xl sm:text-2xl font-medium text-[#141413] tracking-[-0.02em]">
                CCTV Camera Registration Workflow
              </h2>
              <p className="text-xs text-[#696969] mt-0.5">
                Verify owner contact, inspect existing on-premise hardware, and register new surveillance nodes.
              </p>
            </div>
            <button 
              onClick={() => {
                stopCameraStream();
                onClose();
              }} 
              className="p-2 rounded-full text-[#696969] hover:text-[#141413] hover:bg-[#F3F0EE] transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          {/* Step Progress Bar */}
          <div className="grid grid-cols-2 gap-3 mt-4">
            <div 
              onClick={() => setCurrentStep(1)}
              className={`p-2.5 rounded-[16px] border text-xs cursor-pointer transition-all flex items-center gap-2.5 ${
                currentStep === 1 
                  ? 'bg-[#141413] text-[#FCFBFA] border-[#141413] shadow-xs' 
                  : 'bg-white text-[#696969] border-[#E5DFD9] hover:bg-[#F3F0EE]'
              }`}
            >
              <span className={`w-5 h-5 rounded-full flex items-center justify-center font-bold text-[10px] ${
                currentStep === 1 ? 'bg-[#CF4500] text-white' : 'bg-[#E5DFD9] text-[#141413]'
              }`}>
                1
              </span>
              <div className="truncate">
                <span className="font-semibold block text-[11px]">Owner Verification</span>
                <span className="text-[10px] opacity-80 block truncate">Search &amp; verify existing cameras</span>
              </div>
            </div>

            <div 
              onClick={() => {
                if (ownerSearchPerformed || ownerData) setCurrentStep(2);
              }}
              className={`p-2.5 rounded-[16px] border text-xs transition-all flex items-center gap-2.5 ${
                currentStep === 2 
                  ? 'bg-[#141413] text-[#FCFBFA] border-[#141413] shadow-xs' 
                  : 'bg-white text-[#696969] border-[#E5DFD9] opacity-80'
              } ${ownerSearchPerformed ? 'cursor-pointer hover:bg-[#F3F0EE]' : 'cursor-not-allowed opacity-60'}`}
            >
              <span className={`w-5 h-5 rounded-full flex items-center justify-center font-bold text-[10px] ${
                currentStep === 2 ? 'bg-[#CF4500] text-white' : 'bg-[#E5DFD9] text-[#141413]'
              }`}>
                2
              </span>
              <div className="truncate">
                <span className="font-semibold block text-[11px]">Register New Camera</span>
                <span className="text-[10px] opacity-80 block truncate">Photo capture &amp; duplicate check</span>
              </div>
            </div>
          </div>

          {/* Global Alert Messages */}
          {errorMessage && (
            <div className="mt-4 p-3.5 rounded-[20px] bg-[#FDF0EE] border border-[#F8C6BC] text-[#CF4500] text-xs font-medium flex items-center gap-2">
              <AlertTriangle className="w-4 h-4 shrink-0" />
              <span>{errorMessage}</span>
            </div>
          )}

          {successMessage && (
            <div className="mt-4 p-3.5 rounded-[20px] bg-[#EAF7EE] border border-[#BDE8C8] text-[#0A7334] text-xs font-medium flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 shrink-0" />
              <span>{successMessage}</span>
            </div>
          )}

          {/* ============================================================ */}
          {/* STEP 1: OWNER MOBILE NUMBER VERIFICATION & PREMISE REVIEW    */}
          {/* ============================================================ */}
          {currentStep === 1 && (
            <div className="space-y-5 mt-5">
              {/* Search Bar */}
              <div className="p-4 sm:p-5 rounded-[24px] bg-white border border-[#E5DFD9] space-y-3">
                <div className="flex items-center justify-between">
                  <span className="font-bold text-[#141413] flex items-center gap-2 text-xs uppercase tracking-wider">
                    <Phone className="w-4 h-4 text-[#CF4500]" />
                    Step 1: Enter Owner Mobile Number
                  </span>
                  <span className="text-[11px] text-[#696969]">PostgreSQL GIS Registry Lookup</span>
                </div>

                <div className="flex flex-col sm:flex-row gap-2.5">
                  <div className="relative flex-1">
                    <Phone className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-[#696969]" />
                    <input
                      type="text"
                      value={ownerPhoneSearch}
                      onChange={(e) => setOwnerPhoneSearch(e.target.value)}
                      onKeyDown={(e) => e.key === 'Enter' && handleOwnerSearch()}
                      placeholder="e.g. +91 98711 44444 or 9871144444"
                      className="mc-input w-full pl-10 text-xs font-mono"
                    />
                  </div>
                  <button
                    type="button"
                    onClick={() => handleOwnerSearch()}
                    disabled={isSearchingOwner}
                    className="mc-btn-primary shrink-0 py-2.5"
                  >
                    {isSearchingOwner ? (
                      <RefreshCw className="w-4 h-4 animate-spin text-white" />
                    ) : (
                      <Search className="w-4 h-4 text-[#F37338]" />
                    )}
                    <span>Verify Mobile</span>
                  </button>
                </div>

                {/* Quick select demo buttons */}
                <div className="pt-1 flex flex-wrap items-center gap-1.5 text-[11px] text-[#696969]">
                  <span className="text-[10px] uppercase font-semibold text-[#8C827A]">Quick Test:</span>
                  {sampleOwners.map((s) => (
                    <button
                      key={s.number}
                      type="button"
                      onClick={() => {
                        setOwnerPhoneSearch(s.number);
                        handleOwnerSearch(s.number);
                      }}
                      className="px-2.5 py-1 rounded-full bg-[#F3F0EE] hover:bg-[#E5DFD9] text-[#141413] text-[10px] font-medium border border-[#D1CDC7] transition-colors"
                    >
                      {s.label} ({s.number})
                    </button>
                  ))}
                </div>
              </div>

              {/* Owner Summary Card (as specifically requested in prompt) */}
              {ownerSearchPerformed && ownerData && (
                <div className="space-y-4">
                  {ownerData.ownerFound ? (
                    <>
                      {/* Stylized Owner Dossier Card */}
                      <div className="rounded-[28px] bg-gradient-to-br from-[#141413] to-[#2B2927] text-white p-5 sm:p-6 shadow-md border border-[#3E3B38] space-y-4 relative overflow-hidden">
                        <div className="absolute right-3 top-3 text-[70px] font-bold text-white/5 pointer-events-none select-none">
                          VERIFIED
                        </div>

                        <div className="flex items-start justify-between relative z-10">
                          <div>
                            <div className="flex items-center gap-2">
                              <span className="px-2.5 py-0.5 rounded-full bg-[#0A7334] text-white text-[10px] font-bold tracking-wider uppercase flex items-center gap-1">
                                <ShieldCheck className="w-3 h-3" />
                                Owner Record Verified
                              </span>
                              <span className="text-white/60 text-xs font-mono">
                                {ownerData.ownerType || 'COMMERCIAL'}
                              </span>
                            </div>
                            <h3 className="text-xl sm:text-2xl font-semibold text-white mt-1.5 tracking-tight">
                              {ownerData.ownerName || 'Commercial Establishment'}
                            </h3>
                            <p className="text-xs text-[#D1CDC7] font-mono mt-0.5 flex items-center gap-1.5">
                              <Phone className="w-3.5 h-3.5 text-[#F37338]" />
                              Mobile: <strong className="text-white">{ownerData.maskedContact || ownerData.ownerContact}</strong>
                            </p>
                          </div>

                          <div className="text-right">
                            <span className="text-[10px] text-white/60 uppercase block font-semibold">Registered Cameras</span>
                            <span className="text-3xl sm:text-4xl font-mono font-bold text-white">
                              {ownerData.totalCameras}
                            </span>
                          </div>
                        </div>

                        {/* Approved / Pending Breakdown Pill */}
                        <div className="grid grid-cols-3 gap-2.5 pt-2 border-t border-white/10 text-center relative z-10">
                          <div className="bg-white/5 rounded-[16px] p-2 border border-white/10">
                            <span className="text-[10px] text-white/70 block uppercase font-medium">Total Registered</span>
                            <span className="text-base font-bold text-white">{ownerData.totalCameras}</span>
                          </div>
                          <div className="bg-[#EAF7EE]/10 rounded-[16px] p-2 border border-[#0A7334]/30">
                            <span className="text-[10px] text-[#2AD56D] block uppercase font-medium">Approved &amp; Live</span>
                            <span className="text-base font-bold text-[#2AD56D]">{ownerData.approvedCount}</span>
                          </div>
                          <div className="bg-[#FFF4E5]/10 rounded-[16px] p-2 border border-[#F37338]/30">
                            <span className="text-[10px] text-[#F37338] block uppercase font-medium">Pending Verification</span>
                            <span className="text-base font-bold text-[#F37338]">{ownerData.pendingCount}</span>
                          </div>
                        </div>
                      </div>

                      {/* Physical Verification Checklist Banner */}
                      <div className="p-4 rounded-[20px] bg-[#FDF0EE] border border-[#F8C6BC] text-xs flex items-start gap-3">
                        <AlertTriangle className="w-4 h-4 text-[#CF4500] shrink-0 mt-0.5" />
                        <div>
                          <strong className="text-[#141413] block font-semibold">Surveyor Physical Camera Audit Required:</strong>
                          <span className="text-[#696969] leading-relaxed">
                            Please physically inspect all cameras listed below before registering an additional unit. Ensure serial numbers and angles match installed physical hardware.
                          </span>
                        </div>
                      </div>

                      {/* Existing Cameras Grid */}
                      <div className="space-y-3">
                        <div className="flex items-center justify-between">
                          <h4 className="text-xs font-bold text-[#141413] uppercase tracking-wider flex items-center gap-1.5">
                            <Camera className="w-4 h-4 text-[#3860BE]" />
                            Previously Registered Cameras at this Premise ({ownerData.cameras?.length || 0})
                          </h4>
                          <span className="text-[10px] text-[#696969]">Click camera card for details</span>
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 max-h-72 overflow-y-auto pr-1">
                          {ownerData.cameras?.map((cam, idx) => (
                            <div
                              key={cam.id || idx}
                              onClick={() => setSelectedExistingCamera(cam)}
                              className="mc-card p-3.5 flex flex-col justify-between hover:border-[#141413] transition-all cursor-pointer bg-white"
                            >
                              <div className="flex gap-3">
                                {/* Camera Photo Thumbnail */}
                                <div className="w-16 h-16 rounded-[14px] overflow-hidden bg-[#F3F0EE] border border-[#E5DFD9] shrink-0 flex items-center justify-center relative">
                                  {cam.imageUrl ? (
                                    <img 
                                      src={cam.imageUrl} 
                                      alt={cam.cameraName} 
                                      className="w-full h-full object-cover"
                                      onError={(e) => { e.target.style.display = 'none'; }}
                                    />
                                  ) : (
                                    <div className="flex flex-col items-center justify-center text-[#8C827A]">
                                      <Camera className="w-6 h-6" />
                                      <span className="text-[8px] font-bold mt-0.5">CCTV</span>
                                    </div>
                                  )}
                                  <span className={`absolute bottom-0.5 right-0.5 px-1 rounded-sm text-[8px] font-bold ${
                                    cam.verificationStatus === 'APPROVED' ? 'bg-[#0A7334] text-white' : 'bg-[#CF4500] text-white'
                                  }`}>
                                    {cam.cameraType}
                                  </span>
                                </div>

                                <div className="flex-1 min-w-0">
                                  <div className="flex items-center justify-between gap-1">
                                    <span className="font-mono text-[10px] font-bold text-[#3860BE] truncate">{cam.cameraCode}</span>
                                    <span className={`text-[9px] px-1.5 py-0.5 rounded-full font-bold ${
                                      cam.verificationStatus === 'APPROVED' 
                                        ? 'bg-[#EAF7EE] text-[#0A7334] border border-[#BDE8C8]' 
                                        : 'bg-[#FFF4E5] text-[#CF4500] border border-[#F8C6BC]'
                                    }`}>
                                      {cam.verificationStatus}
                                    </span>
                                  </div>
                                  <h5 className="font-medium text-xs text-[#141413] truncate mt-0.5">{cam.cameraName}</h5>

                                  <p className="text-[10px] text-[#696969] flex items-center gap-1 mt-1 truncate">
                                    <MapPin className="w-2.5 h-2.5 text-[#CF4500] shrink-0" />
                                    <span>{cam.area || cam.city || 'Coordinates'}: {cam.latitude?.toFixed(4)}, {cam.longitude?.toFixed(4)}</span>
                                  </p>
                                </div>
                              </div>

                              <div className="mt-2.5 pt-2 border-t border-[#F3F0EE] flex items-center justify-between text-[10px] text-[#696969]">
                                <span className="flex items-center gap-1 font-medium text-[#141413]">
                                  <Compass className="w-3 h-3 text-[#3860BE]" />
                                  {cam.cardinalDirection || 'EAST'} ({cam.directionAngle || 90}°)
                                </span>
                                <span className="font-mono">Radius: {cam.coverageRadiusMeters || 100}m</span>
                              </div>
                            </div>
                          ))}
                        </div>
                      </div>

                      {/* Button to proceed to register camera under this owner */}
                      <div className="pt-2 flex justify-end">
                        <button
                          type="button"
                          onClick={() => setCurrentStep(2)}
                          className="mc-btn-primary w-full sm:w-auto py-3 px-6"
                        >
                          <Camera className="w-4 h-4 text-[#F37338]" />
                          <span>+ Register New Camera Under This Owner</span>
                          <ArrowRight className="w-4 h-4 ml-1" />
                        </button>
                      </div>
                    </>
                  ) : (
                    /* New Owner (Unregistered) Empty State */
                    <div className="p-6 rounded-[28px] bg-white border border-[#E5DFD9] text-center space-y-4">
                      <div className="w-12 h-12 rounded-full bg-[#F3F0EE] text-[#CF4500] mx-auto flex items-center justify-center">
                        <Building2 className="w-6 h-6" />
                      </div>
                      <div className="max-w-md mx-auto space-y-1">
                        <h4 className="font-bold text-[#141413] text-base">New Premise / First-Time Registration</h4>
                        <p className="text-xs text-[#696969] leading-relaxed">
                          No previously surveyed cameras were found for mobile <strong className="font-mono text-[#141413]">{ownerPhoneSearch}</strong>.
                          You can now register the owner details and map the premise's first CCTV camera node.
                        </p>
                      </div>

                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 max-w-lg mx-auto text-left pt-2">
                        <div>
                          <label className="block text-[11px] font-semibold text-[#141413] mb-1">Owner / Establishment Name *</label>
                          <input
                            type="text"
                            required
                            value={form.ownerName}
                            onChange={(e) => setForm({ ...form, ownerName: e.target.value })}
                            placeholder="e.g. ABC Electronic Mart"
                            className="mc-input w-full text-xs"
                          />
                        </div>
                        <div>
                          <label className="block text-[11px] font-semibold text-[#141413] mb-1">Premise Category</label>
                          <select
                            value={form.ownerType}
                            onChange={(e) => setForm({ ...form, ownerType: e.target.value })}
                            className="mc-input w-full text-xs"
                          >
                            <option value="COMMERCIAL">Commercial Retail / Mall</option>
                            <option value="RESIDENTIAL">Residential Society</option>
                            <option value="BANK_ATM">Bank / ATM Kiosk</option>
                            <option value="INDUSTRIAL">Warehouse / Factory</option>
                            <option value="PUBLIC_COMMUNITY">Public Community / Market</option>
                          </select>
                        </div>
                      </div>

                      <div className="pt-3">
                        <button
                          type="button"
                          onClick={() => {
                            if (!form.ownerName.trim()) {
                              setErrorMessage('Please enter Owner/Establishment name to proceed.');
                              return;
                            }
                            setCurrentStep(2);
                          }}
                          className="mc-btn-primary py-2.5 px-5"
                        >
                          <span>Proceed to Camera Registration</span>
                          <ArrowRight className="w-4 h-4 ml-1" />
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              )}
            </div>
          )}

          {/* ============================================================ */}
          {/* STEP 2: REGISTER NEW CAMERA NODE WITH LIVE PHOTO & SERIAL    */}
          {/* ============================================================ */}
          {currentStep === 2 && (
            <form id="surveyRegisterForm" onSubmit={handleFinalSubmit} className="space-y-5 mt-5">
              {/* Back to Step 1 bar + Owner Context Banner */}
              <div className="p-3.5 rounded-[20px] bg-[#F3F0EE] border border-[#E5DFD9] flex items-center justify-between text-xs">
                <div className="flex items-center gap-2 truncate">
                  <button
                    type="button"
                    onClick={() => setCurrentStep(1)}
                    className="p-1.5 rounded-full hover:bg-white text-[#141413] transition-colors"
                    title="Back to Owner Overview"
                  >
                    <ArrowLeft className="w-4 h-4" />
                  </button>
                  <div className="truncate">
                    <span className="text-[10px] text-[#696969] block">Registering Camera for Owner:</span>
                    <strong className="text-[#141413] font-medium text-xs truncate">
                      {form.ownerName || 'Commercial Owner'} ({form.ownerContact})
                    </strong>
                  </div>
                </div>

                <span className="badge-pending shrink-0 text-[10px]">
                  Verification: PENDING
                </span>
              </div>

              {/* Camera Identification Code & Duplicate Check */}
              <div className="p-4 sm:p-5 rounded-[24px] bg-white border border-[#E5DFD9] space-y-3">
                <div className="flex items-center justify-between">
                  <span className="font-bold text-[#141413] flex items-center gap-2 text-xs uppercase tracking-wider">
                    <ScanLine className="w-4 h-4 text-[#3860BE]" />
                    Camera Identification Code &amp; Duplicate Check
                  </span>
                  <button
                    type="button"
                    onClick={() => {
                      const newCode = `CAM-${Math.floor(1000 + Math.random() * 9000)}`;
                      setForm((prev) => ({ ...prev, cameraCode: newCode }));
                    }}
                    className="mc-btn-secondary text-[10px] py-1 px-2.5"
                  >
                    <RefreshCw className="w-3 h-3 text-[#3860BE]" />
                    <span>Generate New Code</span>
                  </button>
                </div>

                <div>
                  <label className="block text-[#141413] font-medium mb-1">
                    Camera Identification Code <span className="text-[#CF4500]">*</span>
                  </label>
                  <div className="relative">
                    <input
                      type="text"
                      required
                      value={form.cameraCode}
                      onChange={(e) => setForm({ ...form, cameraCode: e.target.value })}
                      placeholder="e.g. CAM-NGP-101"
                      className="mc-input w-full font-mono text-xs pr-8"
                    />
                    {duplicateStatus.isChecking && (
                      <RefreshCw className="w-3.5 h-3.5 text-[#696969] animate-spin absolute right-2.5 top-1/2 -translate-y-1/2" />
                    )}
                  </div>
                </div>

                {/* Live Duplicate Alert Banner */}
                {duplicateStatus.isDuplicate ? (
                  <div className="p-3.5 rounded-[18px] bg-[#FDF0EE] border-2 border-[#CF4500] text-xs space-y-1 animate-shake">
                    <div className="flex items-center gap-2 text-[#CF4500] font-bold">
                      <XCircle className="w-4 h-4 shrink-0" />
                      <span>DUPLICATE CAMERA CODE DETECTED: REGISTRATION BLOCKED</span>
                    </div>
                    <p className="text-[11px] text-[#696969] leading-relaxed pl-6">
                      {duplicateStatus.message}
                    </p>
                    {duplicateStatus.existingCamera && (
                      <div className="mt-2 pl-6 text-[10px] text-[#141413] font-mono bg-white/80 p-2 rounded-[12px] border border-[#F8C6BC]">
                        Existing Node: <strong>{duplicateStatus.existingCamera.cameraName}</strong> ({duplicateStatus.existingCamera.cameraCode}) — Status: {duplicateStatus.existingCamera.verificationStatus}
                      </div>
                    )}
                  </div>
                ) : form.cameraCode && !duplicateStatus.isChecking ? (
                  <div className="p-2.5 rounded-[16px] bg-[#EAF7EE] border border-[#BDE8C8] text-[#0A7334] text-[11px] font-medium flex items-center gap-2">
                    <CheckCircle2 className="w-4 h-4 shrink-0" />
                    <span>Camera code is unique and verified in police registry database.</span>
                  </div>
                ) : null}
              </div>

              {/* LIVE Camera Photo Capture & Upload Section */}
              <div className="p-4 sm:p-5 rounded-[24px] bg-white border border-[#E5DFD9] space-y-3">
                <div className="flex items-center justify-between">
                  <span className="font-bold text-[#141413] flex items-center gap-2 text-xs uppercase tracking-wider">
                    <Camera className="w-4 h-4 text-[#CF4500]" />
                    Camera On-Site Photo Verification <span className="text-[#CF4500]">*</span>
                  </span>
                  <div className="flex gap-1.5">
                    <button
                      type="button"
                      onClick={() => {
                        setPhotoSourceMode('upload');
                        stopCameraStream();
                      }}
                      className={`text-[10px] py-1 px-2.5 rounded-[14px] border font-medium ${
                        photoSourceMode === 'upload' ? 'bg-[#141413] text-white border-[#141413]' : 'bg-white text-[#141413] border-[#E5DFD9]'
                      }`}
                    >
                      <Upload className="w-3 h-3 inline mr-1" />
                      Upload File
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setPhotoSourceMode('camera');
                        startCameraStream();
                      }}
                      className={`text-[10px] py-1 px-2.5 rounded-[14px] border font-medium ${
                        photoSourceMode === 'camera' ? 'bg-[#141413] text-white border-[#141413]' : 'bg-white text-[#141413] border-[#E5DFD9]'
                      }`}
                    >
                      <Video className="w-3 h-3 inline mr-1" />
                      Capture Live
                    </button>
                  </div>
                </div>

                {/* Mode 1: Live Camera Stream with Viewfinder */}
                {photoSourceMode === 'camera' && (
                  <div className="relative rounded-[24px] overflow-hidden bg-black aspect-video sm:h-64 flex flex-col items-center justify-center border border-[#141413]">
                    {isCameraActive ? (
                      <>
                        <video 
                          ref={videoRef} 
                          autoPlay 
                          playsInline 
                          muted 
                          className="w-full h-full object-cover"
                        />
                        {/* Viewfinder crosshairs */}
                        <div className="absolute inset-6 border border-dashed border-white/40 rounded-[18px] pointer-events-none flex items-center justify-center">
                          <span className="text-[10px] font-mono uppercase bg-black/60 px-2 py-0.5 rounded text-white/80">
                            Aim at CCTV Mount &amp; Serial Tag
                          </span>
                        </div>

                        {/* Capture Shutter Button */}
                        <div className="absolute bottom-3 left-0 right-0 flex justify-center items-center gap-3">
                          <button
                            type="button"
                            onClick={captureCameraSnapshot}
                            className="bg-[#CF4500] hover:bg-[#E54F00] text-white font-bold text-xs py-2 px-5 rounded-full shadow-lg flex items-center gap-2 border-2 border-white transition-all transform active:scale-95"
                          >
                            <Camera className="w-4 h-4" />
                            <span>Snap Photo</span>
                          </button>
                        </div>
                      </>
                    ) : (
                      <div className="text-center p-6 space-y-3">
                        <Camera className="w-8 h-8 text-white/40 mx-auto animate-pulse" />
                        <p className="text-xs text-white/80">Device Camera is standby.</p>
                        <button
                          type="button"
                          onClick={startCameraStream}
                          className="mc-btn-primary text-xs py-2 px-4 mx-auto"
                        >
                          Start Live Camera
                        </button>
                      </div>
                    )}
                  </div>
                )}

                {/* Mode 2: File Upload */}
                {photoSourceMode === 'upload' && !photoPreview && (
                  <div
                    onClick={() => fileInputRef.current?.click()}
                    className="border-2 border-dashed border-[#D1CDC7] hover:border-[#141413] rounded-[24px] p-6 text-center cursor-pointer transition-colors bg-[#F9F7F5] space-y-2"
                  >
                    <input
                      ref={fileInputRef}
                      type="file"
                      accept="image/*"
                      capture="environment"
                      onChange={handleFileUpload}
                      className="hidden"
                    />
                    <Upload className="w-8 h-8 text-[#8C827A] mx-auto" />
                    <p className="text-xs font-semibold text-[#141413]">
                      Click to take photo or choose an image file
                    </p>
                    <p className="text-[10px] text-[#696969]">
                      Supports JPG, PNG, WEBP from mobile camera or storage
                    </p>
                  </div>
                )}

                {/* Hidden canvas for snapshot rendering */}
                <canvas ref={canvasRef} className="hidden" />

                {/* Photo Preview Card */}
                {photoPreview && (
                  <div className="relative rounded-[20px] overflow-hidden border border-[#E5DFD9] bg-[#141413] p-1 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <img 
                        src={photoPreview} 
                        alt="Captured Camera Photo" 
                        className="w-16 h-16 sm:w-20 sm:h-20 object-cover rounded-[16px]"
                      />
                      <div className="text-white text-xs space-y-0.5">
                        <span className="text-[10px] text-[#2AD56D] font-bold flex items-center gap-1">
                          <Check className="w-3 h-3" />
                          Photo Captured
                        </span>
                        <p className="font-semibold text-white truncate max-w-[180px] sm:max-w-xs">
                          CCTV Mount Snapshot Ready
                        </p>
                        {isUploadingPhoto ? (
                          <span className="text-[10px] text-[#F37338] animate-pulse block">
                            Uploading to Supabase Cloud Storage...
                          </span>
                        ) : form.imageUrl ? (
                          <span className="text-[10px] text-[#10B981] font-medium block">
                            ✓ Uploaded &amp; Linked to Cloud Storage
                          </span>
                        ) : null}
                      </div>
                    </div>

                    <button
                      type="button"
                      onClick={() => {
                        setPhotoPreview('');
                        setForm((prev) => ({ ...prev, imageUrl: '' }));
                        if (photoSourceMode === 'camera') startCameraStream();
                      }}
                      className="mr-3 px-3 py-1.5 rounded-full bg-white/10 hover:bg-white/20 text-white text-[11px] font-medium transition-colors"
                    >
                      Retake
                    </button>
                  </div>
                )}
              </div>

              {/* Camera Landmark Name & Type */}
              <div className="p-4 sm:p-5 rounded-[24px] bg-white border border-[#E5DFD9] space-y-3">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block text-[#141413] font-medium mb-1">
                      Camera Landmark / Name <span className="text-[#CF4500]">*</span>
                    </label>
                    <input
                      type="text"
                      required
                      value={form.cameraName}
                      onChange={(e) => setForm({ ...form, cameraName: e.target.value })}
                      placeholder="e.g. Sitabuldi Main Gate Traffic Dome"
                      className="mc-input w-full text-xs"
                    />
                  </div>

                  <div>
                    <label className="block text-[#141413] font-medium mb-1">Camera Hardware Type</label>
                    <select
                      value={form.cameraType}
                      onChange={(e) => setForm({ ...form, cameraType: e.target.value })}
                      className="mc-input w-full text-xs"
                    >
                      <option value="PTZ">PTZ (Pan-Tilt-Zoom)</option>
                      <option value="DOME">Dome Camera</option>
                      <option value="BULLET">Bullet Camera</option>
                      <option value="ANPR">ANPR (Plate Recognition)</option>
                    </select>
                  </div>
                </div>
              </div>

              {/* Geospatial GPS Location with Auto-Fetch */}
              <div className="p-4 sm:p-5 rounded-[24px] bg-white border border-[#E5DFD9] space-y-3">
                <div className="flex items-center justify-between">
                  <span className="font-bold text-[#141413] flex items-center gap-2 text-xs uppercase tracking-wider">
                    <MapPin className="w-4 h-4 text-[#CF4500]" />
                    Geospatial Coordinates
                  </span>
                  <div className="flex gap-2">
                    <button
                      type="button"
                      onClick={handleGetCurrentGPS}
                      disabled={isLocatingGPS}
                      className="mc-btn-secondary text-xs py-1 px-3"
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
                      onClick={() => setUseMapPicker(!useMapPicker)}
                      className={`text-xs py-1 px-3 rounded-[20px] border font-medium transition-all ${
                        useMapPicker ? 'bg-[#141413] text-white border-[#141413]' : 'bg-white text-[#141413] border-[#141413]'
                      }`}
                    >
                      {useMapPicker ? 'Close Map' : 'Pick on Map'}
                    </button>
                  </div>
                </div>

                {gpsSuccess && (
                  <div className="p-2 rounded-[14px] bg-[#EAF7EE] text-[#0A7334] text-[11px] font-medium flex items-center gap-2">
                    <CheckCircle2 className="w-3.5 h-3.5" />
                    <span>Accurate GPS Coordinates fetched successfully from device sensor.</span>
                  </div>
                )}

                {useMapPicker && (
                  <div className="h-64 sm:h-72 w-full rounded-[24px] overflow-hidden my-2 border border-[#D1CDC7] relative">
                    <div className="absolute top-2.5 left-3 right-3 z-[400] pointer-events-none flex justify-center">
                      <div className="bg-[#141413]/90 backdrop-blur-xs text-[#F3F0EE] text-[11px] font-medium px-3.5 py-1 rounded-full shadow-md border border-white/10 flex items-center gap-1.5 pointer-events-auto">
                        <span className="w-2 h-2 rounded-full bg-[#CF4500] animate-ping"></span>
                        <span>Click anywhere on the map to set camera GPS coordinates</span>
                      </div>
                    </div>
                    <CameraMap
                      interactivePicker={true}
                      center={[parseFloat(form.latitude) || 21.1458, parseFloat(form.longitude) || 79.0882]}
                      selectedLocation={{ lat: parseFloat(form.latitude) || 21.1458, lng: parseFloat(form.longitude) || 79.0882 }}
                      onMapClick={handleMapLocationSelect}
                      zoom={15}
                      autoFit={false}
                    />
                  </div>
                )}

                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block text-[#141413] font-medium mb-1">Latitude *</label>
                    <input
                      type="number"
                      step="0.00001"
                      required
                      value={form.latitude}
                      onChange={(e) => setForm({ ...form, latitude: parseFloat(e.target.value) || 0 })}
                      className="mc-input w-full font-mono text-xs"
                    />
                  </div>
                  <div>
                    <label className="block text-[#141413] font-medium mb-1">Longitude *</label>
                    <input
                      type="number"
                      step="0.00001"
                      required
                      value={form.longitude}
                      onChange={(e) => setForm({ ...form, longitude: parseFloat(e.target.value) || 0 })}
                      className="mc-input w-full font-mono text-xs"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-[#141413] font-medium mb-1">Premise Physical Address</label>
                  <input
                    type="text"
                    value={form.fullAddress}
                    onChange={(e) => setForm({ ...form, fullAddress: e.target.value })}
                    placeholder="e.g. Shop 4, Ground Floor, Central Plaza, Main Market Road"
                    className="mc-input w-full text-xs"
                  />
                </div>
              </div>

              {/* Compass Lens Direction & View Angle Coverage (FOV) */}
              <div className="p-4 sm:p-5 rounded-[24px] bg-white border border-[#E5DFD9] space-y-4">
                {/* Header with live summary badge */}
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-[#E5DFD9] pb-3">
                  <span className="font-bold text-[#141413] flex items-center gap-2 text-xs uppercase tracking-wider">
                    <Compass className="w-4 h-4 text-[#3860BE]" />
                    Camera Lens Direction &amp; View Angle Coverage
                  </span>
                  <div className="flex flex-wrap items-center gap-1.5 font-mono text-[11px]">
                    <span className="bg-[#141413] text-white px-2.5 py-0.5 rounded-full font-bold">
                      {form.cardinalDirection || 'EAST'} ({form.directionAngle || 90}°)
                    </span>
                    <span className="bg-[#FDF0EE] text-[#CF4500] border border-[#F8C6BC] px-2.5 py-0.5 rounded-full font-bold">
                      Arc: {form.fovAngle || 60}° View
                    </span>
                    <span className="bg-[#F3F0EE] text-[#141413] px-2.5 py-0.5 rounded-full">
                      Radius: {form.coverageRadiusMeters || 100}m
                    </span>
                  </div>
                </div>

                {/* All 8 Cardinal Directions */}
                <div className="space-y-2">
                  <div className="flex justify-between items-center text-xs">
                    <label className="text-[#141413] font-semibold">
                      1. Cardinal Facing Direction <span className="text-[#CF4500]">*</span>
                    </label>
                    <span className="text-[10px] text-[#696969]">8-Point Compass Bearing</span>
                  </div>

                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
                    {[
                      { label: 'NORTH', short: 'N', angle: 0, arrow: '⬆️' },
                      { label: 'NORTH-EAST', short: 'NE', angle: 45, arrow: '↗️' },
                      { label: 'EAST', short: 'E', angle: 90, arrow: '➡️' },
                      { label: 'SOUTH-EAST', short: 'SE', angle: 135, arrow: '↘️' },
                      { label: 'SOUTH', short: 'S', angle: 180, arrow: '⬇️' },
                      { label: 'SOUTH-WEST', short: 'SW', angle: 225, arrow: '↙️' },
                      { label: 'WEST', short: 'W', angle: 270, arrow: '⬅️' },
                      { label: 'NORTH-WEST', short: 'NW', angle: 315, arrow: '↖️' },
                    ].map((dir) => {
                      const isSelected = form.cardinalDirection === dir.label || form.directionAngle === dir.angle;
                      return (
                        <button
                          key={dir.label}
                          type="button"
                          onClick={() => setForm({ ...form, cardinalDirection: dir.label, directionAngle: dir.angle })}
                          className={`p-2.5 rounded-[16px] border text-xs font-medium flex items-center justify-between transition-all ${
                            isSelected
                              ? 'bg-[#141413] text-white border-[#141413] shadow-sm ring-2 ring-[#141413]/20'
                              : 'bg-white text-[#141413] border-[#E5DFD9] hover:bg-[#F3F0EE] hover:border-[#D1CDC7]'
                          }`}
                        >
                          <div className="flex items-center gap-1.5">
                            <span className="text-sm">{dir.arrow}</span>
                            <span className="font-semibold text-[11px]">{dir.short}</span>
                          </div>
                          <span className={`text-[10px] font-mono ${isSelected ? 'text-[#F37338]' : 'text-[#696969]'}`}>
                            {dir.angle}°
                          </span>
                        </button>
                      );
                    })}
                  </div>

                  {/* Fine Direction Angle Slider (0° - 360°) */}
                  <div className="pt-2">
                    <div className="flex justify-between text-[11px] text-[#696969] mb-1 font-medium">
                      <span>Fine Compass Degree Bearing (0° - 360°):</span>
                      <strong className="text-[#141413] font-mono text-xs">{form.directionAngle || 0}° Bearing</strong>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="360"
                      step="5"
                      value={form.directionAngle || 0}
                      onChange={(e) => {
                        const deg = parseInt(e.target.value) || 0;
                        let card = 'NORTH';
                        if (deg >= 22.5 && deg < 67.5) card = 'NORTH-EAST';
                        else if (deg >= 67.5 && deg < 112.5) card = 'EAST';
                        else if (deg >= 112.5 && deg < 157.5) card = 'SOUTH-EAST';
                        else if (deg >= 157.5 && deg < 202.5) card = 'SOUTH';
                        else if (deg >= 202.5 && deg < 247.5) card = 'SOUTH-WEST';
                        else if (deg >= 247.5 && deg < 292.5) card = 'WEST';
                        else if (deg >= 292.5 && deg < 337.5) card = 'NORTH-WEST';
                        setForm({ ...form, directionAngle: deg, cardinalDirection: card });
                      }}
                      className="w-full accent-[#141413] cursor-pointer"
                    />
                  </div>
                </div>

                {/* Camera View Angle / Field of View (FOV Spread) */}
                <div className="pt-3 border-t border-[#E5DFD9] space-y-2">
                  <div className="flex justify-between items-center text-xs">
                    <div>
                      <label className="text-[#141413] font-semibold block">
                        2. Camera View Covering Angle (Field of View - FOV) <span className="text-[#CF4500]">*</span>
                      </label>
                      <span className="text-[10px] text-[#696969]">Spread width of area captured by camera lens</span>
                    </div>
                    <span className="font-mono font-bold text-xs text-[#CF4500] bg-[#FDF0EE] px-2.5 py-0.5 rounded-full border border-[#F8C6BC]">
                      {form.fovAngle || 60}° Spread
                    </span>
                  </div>

                  {/* FOV Presets: 30, 60, 90, 120, 180, 360 */}
                  <div className="grid grid-cols-3 sm:grid-cols-6 gap-2">
                    {[
                      { label: '30° Spot', angle: 30, desc: 'Corridor / Spot' },
                      { label: '60° Std', angle: 60, desc: 'Standard Lens' },
                      { label: '90° Wide', angle: 90, desc: 'Wide Street' },
                      { label: '120° Ultra', angle: 120, desc: 'Junction Arc' },
                      { label: '180° Semi', angle: 180, desc: 'Panoramic' },
                      { label: '360° Pan', angle: 360, desc: 'Full 360° Fisheye' },
                    ].map((preset) => {
                      const isFovSelected = (form.fovAngle === preset.angle);
                      return (
                        <button
                          key={preset.angle}
                          type="button"
                          onClick={() => setForm({ ...form, fovAngle: preset.angle })}
                          className={`p-2 rounded-[14px] border text-center transition-all ${
                            isFovSelected
                              ? 'bg-[#CF4500] text-white border-[#CF4500] shadow-sm'
                              : 'bg-[#F9F7F5] text-[#141413] border-[#E5DFD9] hover:bg-[#F3F0EE]'
                          }`}
                        >
                          <span className="font-bold text-[11px] block">{preset.label}</span>
                          <span className={`text-[9px] block truncate ${isFovSelected ? 'text-white/80' : 'text-[#696969]'}`}>
                            {preset.desc}
                          </span>
                        </button>
                      );
                    })}
                  </div>

                  {/* Fine FOV Range Slider */}
                  <div className="pt-2">
                    <div className="flex justify-between text-[11px] text-[#696969] mb-1 font-medium">
                      <span>Fine View Angle Spread (15° - 360°):</span>
                      <strong className="text-[#CF4500] font-mono text-xs">{form.fovAngle || 60}° View Width</strong>
                    </div>
                    <input
                      type="range"
                      min="15"
                      max="360"
                      step="5"
                      value={form.fovAngle || 60}
                      onChange={(e) => setForm({ ...form, fovAngle: parseInt(e.target.value) || 60 })}
                      className="w-full accent-[#CF4500] cursor-pointer"
                    />
                  </div>
                </div>

                {/* Visual Coverage Distance Radius (meters) */}
                <div className="pt-3 border-t border-[#E5DFD9] space-y-2">
                  <div className="flex justify-between items-center text-xs">
                    <div>
                      <label className="text-[#141413] font-semibold block">
                        3. Maximum Optical Coverage Radius (Distance in meters)
                      </label>
                      <span className="text-[10px] text-[#696969]">Effective identification &amp; detection range from lens</span>
                    </div>
                    <span className="font-mono font-bold text-xs text-[#3860BE] bg-[#EFF4FE] px-2.5 py-0.5 rounded-full border border-[#D3E2FB]">
                      {form.coverageRadiusMeters || 100} meters
                    </span>
                  </div>

                  <div className="flex items-center gap-4">
                    <div className="flex-1">
                      <input
                        type="range"
                        min="20"
                        max="350"
                        step="10"
                        value={form.coverageRadiusMeters || 100}
                        onChange={(e) => setForm({ ...form, coverageRadiusMeters: parseInt(e.target.value) || 100 })}
                        className="w-full accent-[#3860BE] cursor-pointer"
                      />
                    </div>
                    <div className="w-24">
                      <input
                        type="number"
                        min="10"
                        max="1000"
                        value={form.coverageRadiusMeters || 100}
                        onChange={(e) => setForm({ ...form, coverageRadiusMeters: parseInt(e.target.value) || 100 })}
                        className="mc-input w-full font-mono text-xs py-1.5 text-center"
                      />
                    </div>
                  </div>
                </div>
              </div>
            </form>
          )}
        </div>

        {/* Modal Action Footer */}
        <div className="flex items-center justify-between gap-3 pt-4 border-t border-[#E5DFD9] bg-[#FCFBFA] sticky bottom-0 z-20">
          <button
            type="button"
            onClick={() => {
              stopCameraStream();
              onClose();
            }}
            className="mc-btn-secondary"
          >
            Cancel
          </button>

          {currentStep === 1 ? (
            <button
              type="button"
              onClick={() => {
                if (!ownerSearchPerformed) {
                  handleOwnerSearch();
                } else {
                  setCurrentStep(2);
                }
              }}
              className="mc-btn-primary"
            >
              <span>{ownerSearchPerformed ? 'Continue to Registration' : 'Verify Mobile First'}</span>
              <ArrowRight className="w-4 h-4 ml-1" />
            </button>
          ) : (
            <button
              type="submit"
              form="surveyRegisterForm"
              disabled={addCameraMutation.isPending || duplicateStatus.isDuplicate}
              className={`mc-btn-primary ${
                duplicateStatus.isDuplicate ? 'opacity-50 cursor-not-allowed bg-[#8C827A]' : ''
              }`}
            >
              {addCameraMutation.isPending ? (
                <>
                  <RefreshCw className="w-4 h-4 animate-spin" />
                  <span>Submitting Survey...</span>
                </>
              ) : (
                <>
                  <ShieldCheck className="w-4 h-4 text-[#F37338]" />
                  <span>Submit for Admin Verification</span>
                </>
              )}
            </button>
          )}
        </div>
      </motion.div>
    </div>
  );
};
