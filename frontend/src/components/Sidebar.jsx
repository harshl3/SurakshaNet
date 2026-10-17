import React from 'react';
import { NavLink } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { 
  LayoutDashboard, 
  Camera, 
  FileSearch, 
  CheckCircle2, 
  Building2, 
  ClipboardList, 
  Shield, 
  X, 
  User, 
  LogOut,
  BadgeCheck
} from 'lucide-react';

export const Sidebar = ({ isMobileOpen, onCloseMobile }) => {
  const { user, logout } = useAuth();
  const userRole = typeof user?.role === 'object' ? user?.role?.name : user?.role;

  const navItems = [
    { label: 'GIS Command & Map', path: '/dashboard', icon: LayoutDashboard, roles: ['ROLE_ADMIN', 'ROLE_POLICE_OFFICER', 'ROLE_SURVEY_PERSON'] },
    { label: 'Crime Investigations', path: '/investigations', icon: FileSearch, roles: ['ROLE_ADMIN', 'ROLE_POLICE_OFFICER'] },
    { label: 'CCTV Camera Directory', path: '/cameras', icon: Camera, roles: ['ROLE_ADMIN', 'ROLE_POLICE_OFFICER', 'ROLE_SURVEY_PERSON'] },
    { label: 'Verification Queue', path: '/verification', icon: CheckCircle2, roles: ['ROLE_ADMIN'] },
    { label: 'My Field Surveys', path: '/my-surveys', icon: ClipboardList, roles: ['ROLE_SURVEY_PERSON'] },
  ];

  const visibleItems = navItems.filter(item => item.roles.includes(userRole));

  const getRoleLabel = (role) => {
    switch (role) {
      case 'ROLE_ADMIN':
        return 'Central Police Admin';
      case 'ROLE_POLICE_OFFICER':
        return 'Police Investigation Officer';
      case 'ROLE_SURVEY_PERSON':
        return 'Field Camera Surveyor';
      default:
        return 'Authorized Official';
    }
  };

  const content = (
    <div className="flex flex-col justify-between h-full p-3.5 sm:p-4 overflow-y-auto no-scrollbar space-y-2.5">
      <div className="space-y-2.5">
        {/* Mobile Drawer Header with Logo & Close Toggle */}
        <div className="flex items-center justify-between md:hidden pb-3 border-b border-[#262627]">
          <div className="flex items-center gap-2.5">
            <img 
              src="/police-logo.png" 
              alt="Police Department Logo" 
              className="w-8 h-8 object-contain shrink-0" 
            />
            <div>
              <span className="font-bold text-white text-sm block leading-tight">SurakshaNet</span>
              <span className="text-[10px] text-[#D1CDC7] font-mono">Police Investigation GIS</span>
            </div>
          </div>
          <button 
            onClick={onCloseMobile}
            className="p-2 rounded-full text-[#D1CDC7] hover:text-white hover:bg-white/10 transition-colors"
            aria-label="Close navigation"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* ------------------------------------------------------------- */}
        {/* MOBILE VIEW ONLY: DEDICATED PROFILE CARD                     */}
        {/* ------------------------------------------------------------- */}
        <div className="md:hidden p-4 rounded-[28px] bg-[#1C1C1A] border border-white/10 space-y-3.5 shadow-lg">
          <div className="flex items-center gap-3">
            {/* User Avatar Circle */}
            <div className="w-11 h-11 rounded-full bg-white text-[#141413] flex items-center justify-center font-bold text-base shrink-0 shadow-md">
              {user?.fullName?.charAt(0) || <User className="w-5 h-5 text-[#141413]" />}
            </div>

            <div className="min-w-0 flex-1">
              <div className="flex items-center gap-1.5">
                <p className="text-sm font-bold text-white truncate leading-tight">
                  {user?.fullName || 'Police Official'}
                </p>
                <BadgeCheck className="w-3.5 h-3.5 text-[#F37338] shrink-0" />
              </div>
              <p className="text-[11px] font-mono text-[#D1CDC7] truncate mt-0.5">
                Badge: @{user?.username || 'officer'}
              </p>
            </div>
          </div>

          {/* Role & Police Station Jurisdiction Pills */}
          <div className="space-y-1.5 pt-1 border-t border-white/10 text-xs">
            <div className="flex items-center justify-between">
              <span className="text-[10px] uppercase tracking-wider font-semibold text-[#696969]">Jurisdiction</span>
              <span className="text-[10px] font-mono font-bold text-[#F37338] px-2 py-0.5 rounded-full bg-[#F37338]/10 border border-[#F37338]/20">
                {userRole ? userRole.replace('ROLE_', '') : 'OFFICER'}
              </span>
            </div>
            <p className="text-[11px] text-[#D1CDC7] flex items-center gap-1.5 leading-snug">
              <Building2 className="w-3.5 h-3.5 text-[#CF4500] shrink-0" />
              <span>{user?.policeStationName || 'Central District Command Station'}</span>
            </p>
          </div>
        </div>

        {/* Eyebrow Category */}
        <div className="px-2 pt-0.5">
          <span className="text-[10px] font-bold tracking-[+0.06em] text-[#D1CDC7] uppercase flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-[#F37338]"></span>
            INVESTIGATION MODULES
          </span>
        </div>

        {/* Navigation Items in Stadium/Pill Shape */}
        <nav className="flex flex-col gap-1.5">
          {visibleItems.map((item) => {
            const Icon = item.icon;
            return (
              <NavLink
                key={item.path}
                to={item.path}
                onClick={onCloseMobile}
                className={({ isActive }) =>
                  `flex items-center gap-3 px-4 py-2.5 rounded-full text-xs font-medium tracking-tight transition-all duration-150 ${
                    isActive
                      ? 'bg-white text-[#141413] font-bold shadow-md'
                      : 'text-[#D1CDC7] hover:text-white hover:bg-white/5'
                  }`
                }
              >
                {({ isActive }) => (
                  <>
                    <Icon className={`w-4 h-4 shrink-0 ${isActive ? 'text-[#CF4500]' : 'text-[#D1CDC7]'}`} />
                    <span className="truncate">{item.label}</span>
                    {isActive && (
                      <span className="w-1.5 h-1.5 rounded-full bg-[#CF4500] ml-auto shrink-0"></span>
                    )}
                  </>
                )}
              </NavLink>
            );
          })}
        </nav>
      </div>

      {/* Footer / Bottom Actions: Station precinct, Sign Out Button, and branding seal */}
      <div className="space-y-3 pt-3 border-t border-[#262627] shrink-0">
        {/* Desktop station precinct indicator - NO TRUNCATION */}
        <div className="hidden md:block p-3.5 rounded-[20px] bg-[#1C1C1A] border border-white/10 text-xs space-y-1.5">
          <div className="flex items-center justify-between text-[10px] text-[#8C8882] uppercase font-semibold">
            <span className="flex items-center gap-1.5">
              <Building2 className="w-3.5 h-3.5 text-[#F37338] shrink-0" />
              Station Precinct
            </span>
            <span className="text-[9px] font-mono text-[#F37338] bg-[#F37338]/10 px-1.5 py-0.5 rounded border border-[#F37338]/20">HQ</span>
          </div>
          <p className="font-semibold text-white text-xs leading-snug break-words">
            {user?.policeStationName || 'Central District Command Station'}
          </p>
          <div className="pt-2 border-t border-white/5 flex items-center justify-between text-[10px] text-[#8C8882] font-mono">
            <span>Badge: @{user?.username || 'officer1'}</span>
            <span className="text-[#10B981]">Active Shift</span>
          </div>
        </div>

        {/* PROMINENT LOGOUT / SIGN OUT BUTTON AT THE VERY BOTTOM */}
        <button
          onClick={() => {
            if (onCloseMobile) onCloseMobile();
            logout();
          }}
          className="w-full flex items-center justify-center gap-2 py-2.5 px-4 rounded-[18px] bg-[#CF4500] hover:bg-[#B53C00] active:scale-[0.98] text-white font-semibold text-xs tracking-tight shadow-md transition-all cursor-pointer"
        >
          <LogOut className="w-4 h-4" />
          <span>Exit &amp; Sign Out</span>
        </button>

        {/* Official Seal */}
        <div className="text-[#8C8882] px-1 flex items-center justify-between text-[10px] font-mono">
          <span className="text-[#D1CDC7] font-semibold tracking-wider">CCTNS POLICE GIS</span>
          <span>v2.4 SECURE</span>
        </div>
      </div>
    </div>
  );

  return (
    <>
      {/* Desktop Persistent Sticky Sidebar with Full Viewport Height & Clean Gap Below Navbar */}
      <aside className="w-64 lg:w-70 bg-[#141413] hidden md:flex flex-col shrink-0 select-none sticky top-[6.25rem] self-start h-[calc(100vh-7.75rem)] max-h-[calc(100vh-7.75rem)] ml-4 lg:ml-6 mt-2 mb-4 rounded-[32px] border border-white/10 shadow-2xl overflow-hidden no-scrollbar z-20">
        {content}
      </aside>

      {/* Mobile Slide-over Drawer Backdrop */}
      {isMobileOpen && (
        <div 
          className="fixed inset-0 bg-[#141413]/70 backdrop-blur-xs z-[120] md:hidden transition-opacity"
          onClick={onCloseMobile}
        />
      )}

      {/* Mobile Slide-over Drawer (Opens from the right side) */}
      <aside 
        className={`fixed top-0 bottom-0 right-0 w-80 max-w-[86vw] bg-[#141413] z-[120] md:hidden shadow-2xl transition-transform duration-200 ease-in-out no-scrollbar ${
          isMobileOpen ? 'translate-x-0' : 'translate-x-full'
        }`}
      >
        {content}
      </aside>
    </>
  );
};
