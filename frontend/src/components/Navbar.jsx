import React from 'react';
import { useAuth } from '../context/AuthContext';
import { LogOut, User, Building2, Menu, X } from 'lucide-react';

export const Navbar = ({ onToggleMobileSidebar, isMobileSidebarOpen }) => {
  const { user, logout } = useAuth();
  const userRole = typeof user?.role === 'object' ? user?.role?.name : user?.role;

  const getRolePill = (role) => {
    switch (role) {
      case 'ROLE_ADMIN':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold tracking-wide bg-[#141413] text-[#F3F0EE]">
            <span className="w-1.5 h-1.5 rounded-full bg-[#CF4500]"></span>
            ADMIN COMMAND
          </span>
        );
      case 'ROLE_POLICE_OFFICER':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold tracking-wide bg-[#141413] text-[#F3F0EE]">
            <span className="w-1.5 h-1.5 rounded-full bg-[#F37338]"></span>
            INVESTIGATION OFFICER
          </span>
        );
      case 'ROLE_SURVEY_PERSON':
        return (
          <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold tracking-wide bg-[#141413] text-[#F3F0EE]">
            <span className="w-1.5 h-1.5 rounded-full bg-[#F79E1B]"></span>
            FIELD SURVEYOR
          </span>
        );
      default:
        return null;
    }
  };

  return (
    <div className="w-full px-3 sm:px-6 pt-3 sm:pt-4 sticky top-0 z-[100] pointer-events-none">
      <header className="h-14 sm:h-16 md:h-18 max-w-[1520px] mx-auto bg-white/95 backdrop-blur-md rounded-full px-4 sm:px-6 flex items-center justify-between border border-[#E5DFD9] shadow-mc-nav pointer-events-auto transition-all">
        
        {/* ========================================================= */}
        {/* LEFT: Official Police Department Logo & SurakshaNet Title */}
        {/* ========================================================= */}
        <div className="flex items-center gap-2.5 sm:gap-3 min-w-0">
          <img 
            src="/police-logo.png" 
            alt="Police Department Emblem" 
            className="w-8 h-8 sm:w-10 sm:h-10 object-contain shrink-0 drop-shadow-xs" 
          />

          <div className="flex flex-col">
            <div className="flex items-center gap-1.5 sm:gap-2">
              <span className="font-extrabold text-sm sm:text-base md:text-lg text-[#141413] tracking-[-0.02em] leading-tight">
                SurakshaNet
              </span>
              <span className="hidden sm:inline-flex items-center gap-1 text-[10px] bg-[#F3F0EE] text-[#141413] px-2 py-0.5 rounded-full font-mono font-semibold border border-[#E5DFD9]">
                POLICE GIS
              </span>
            </div>
            <p className="hidden md:flex text-[11px] text-[#696969] items-center gap-1 font-medium truncate mt-0.5">
              <Building2 className="w-3 h-3 text-[#CF4500] shrink-0" />
              <span className="truncate max-w-xs md:max-w-md">
                {user?.policeStationName || 'Central Metropolitan Police Command HQ'}
              </span>
            </p>
          </div>
        </div>

        {/* ========================================================= */}
        {/* RIGHT: Mobile Toggle Button (Right) & Desktop Profile     */}
        {/* ========================================================= */}
        <div className="flex items-center gap-2 sm:gap-3 shrink-0">
          
          {/* MOBILE TOGGLE BUTTON (Placed cleanly at the right, opens right-side drawer) */}
          <button
            type="button"
            onClick={onToggleMobileSidebar}
            className="md:hidden p-2 rounded-full text-[#141413] hover:bg-[#F3F0EE] active:scale-95 transition-all flex items-center justify-center shrink-0 border border-[#E5DFD9]"
            aria-label="Toggle Navigation Menu"
          >
            {isMobileSidebarOpen ? <X className="w-5 h-5 text-[#CF4500]" /> : <Menu className="w-5 h-5" />}
          </button>

          {/* DESKTOP ROLE PILL, PROFILE CHIP & LOGOUT BUTTON */}
          <div className="hidden md:flex items-center gap-2.5 sm:gap-3">
            <div className="hidden lg:block">
              {getRolePill(userRole)}
            </div>

            {/* Desktop User Info Chip */}
            <div className="flex items-center gap-2 pl-1">
              <div className="w-8 h-8 sm:w-9 sm:h-9 rounded-full bg-[#141413] text-[#F3F0EE] flex items-center justify-center font-bold text-xs shadow-xs">
                {user?.fullName?.charAt(0) || <User className="w-4 h-4" />}
              </div>
              <div className="text-left">
                <p className="text-xs font-bold text-[#141413] leading-none truncate max-w-[120px]">
                  {user?.fullName || 'Police Official'}
                </p>
                <p className="text-[10px] font-mono text-[#696969] mt-0.5 truncate max-w-[120px]">
                  {user?.username}
                </p>
              </div>
            </div>

            {/* Desktop Logout Button */}
            <button
              onClick={logout}
              title="Sign out of portal"
              className="flex items-center gap-1.5 px-3.5 py-1.5 rounded-full bg-white hover:bg-[#F3F0EE] text-[#141413] border border-[#141413] text-xs font-medium tracking-tight transition-all"
            >
              <LogOut className="w-3.5 h-3.5 text-[#CF4500]" />
              <span>Logout</span>
            </button>
          </div>
        </div>

      </header>
    </div>
  );
};
