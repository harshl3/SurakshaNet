import React, { useState } from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { useAuth } from './context/AuthContext';
import { Navbar } from './components/Navbar';
import { Sidebar } from './components/Sidebar';
import { BottomNav } from './components/BottomNav';
import { Login } from './pages/Login';
import { Dashboard } from './pages/Dashboard';
import { CameraList } from './pages/CameraList';
import { InvestigationView } from './pages/InvestigationView';
import { VerificationQueue } from './pages/VerificationQueue';
import { MyFieldSurveys } from './pages/MyFieldSurveys';
import { ShieldAlert } from 'lucide-react';

const ProtectedLayout = ({ children, allowedRoles }) => {
  const { user } = useAuth();
  const [isMobileSidebarOpen, setIsMobileSidebarOpen] = useState(false);

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  const userRole = typeof user?.role === 'object' ? user?.role?.name : user?.role;

  if (allowedRoles && userRole && !allowedRoles.includes(userRole)) {
    return (
      <div className="min-h-screen bg-[#F3F0EE] text-[#141413] flex flex-col">
        <Navbar 
          onToggleMobileSidebar={() => setIsMobileSidebarOpen(!isMobileSidebarOpen)} 
          isMobileSidebarOpen={isMobileSidebarOpen} 
        />
        <div className="flex-1 flex items-start overflow-visible relative">
          <Sidebar 
            isMobileOpen={isMobileSidebarOpen} 
            onCloseMobile={() => setIsMobileSidebarOpen(false)} 
          />
          <main className="flex-1 min-w-0 p-4 md:p-8 flex items-center justify-center pb-24 md:pb-8">
            <div className="mc-stadium max-w-md w-full p-6 md:p-8 text-center space-y-4 border-l-4 border-l-[#CF4500]">
              <ShieldAlert className="w-12 h-12 text-[#CF4500] mx-auto" />
              <div>
                <h3 className="text-lg font-bold text-[#141413]">Access Restricted (403 Forbidden)</h3>
                <p className="text-xs text-[#696969] mt-2 leading-relaxed">
                  Your authorized role <span className="font-mono font-bold text-[#CF4500] bg-[#FDF0EE] px-2 py-0.5 rounded-full border border-[#F8C6BC]">({userRole || 'ROLE_SURVEY_PERSON'})</span> does not have authorization to view this police investigation section.
                </p>
              </div>
            </div>
          </main>
        </div>
        <BottomNav onOpenMobileMenu={() => setIsMobileSidebarOpen(true)} />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#F3F0EE] text-[#141413] flex flex-col selection:bg-[#CF4500] selection:text-white">
      <Navbar 
        onToggleMobileSidebar={() => setIsMobileSidebarOpen(!isMobileSidebarOpen)} 
        isMobileSidebarOpen={isMobileSidebarOpen} 
      />
      <div className="flex-1 flex items-start overflow-visible relative">
        <Sidebar 
          isMobileOpen={isMobileSidebarOpen} 
          onCloseMobile={() => setIsMobileSidebarOpen(false)} 
        />
        <main className="flex-1 min-w-0 p-3.5 sm:p-5 md:p-6 lg:p-7 max-w-[1520px] mx-auto pb-24 md:pb-8">
          {children}
        </main>
      </div>
      {/* Mobile Floating Bottom Navigation Bar */}
      <BottomNav onOpenMobileMenu={() => setIsMobileSidebarOpen(true)} />
    </div>
  );
};

export const App = () => {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route
        path="/dashboard"
        element={
          <ProtectedLayout allowedRoles={['ROLE_ADMIN', 'ROLE_POLICE_OFFICER', 'ROLE_SURVEY_PERSON']}>
            <Dashboard />
          </ProtectedLayout>
        }
      />
      <Route
        path="/map"
        element={
          <ProtectedLayout allowedRoles={['ROLE_ADMIN', 'ROLE_POLICE_OFFICER', 'ROLE_SURVEY_PERSON']}>
            <Dashboard />
          </ProtectedLayout>
        }
      />
      <Route
        path="/cameras"
        element={
          <ProtectedLayout allowedRoles={['ROLE_ADMIN', 'ROLE_POLICE_OFFICER', 'ROLE_SURVEY_PERSON']}>
            <CameraList />
          </ProtectedLayout>
        }
      />
      <Route
        path="/investigations"
        element={
          <ProtectedLayout allowedRoles={['ROLE_ADMIN', 'ROLE_POLICE_OFFICER']}>
            <InvestigationView />
          </ProtectedLayout>
        }
      />
      <Route
        path="/verification"
        element={
          <ProtectedLayout allowedRoles={['ROLE_ADMIN']}>
            <VerificationQueue />
          </ProtectedLayout>
        }
      />
      <Route
        path="/my-surveys"
        element={
          <ProtectedLayout allowedRoles={['ROLE_SURVEY_PERSON']}>
            <MyFieldSurveys />
          </ProtectedLayout>
        }
      />
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  );
};
