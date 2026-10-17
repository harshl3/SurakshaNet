import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AuthProvider } from './context/AuthContext';
import { App } from './App';
import './index.css';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
});

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error("Critical Application Error caught by ErrorBoundary:", error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-[#F3F0EE] flex items-center justify-center p-4">
          <div className="mc-stadium max-w-lg w-full p-6 sm:p-8 bg-white text-center space-y-4 shadow-xl border border-[#E5DFD9]">
            <div className="w-14 h-14 rounded-full bg-[#FDF0EE] text-[#CF4500] flex items-center justify-center mx-auto text-2xl font-bold">
              !
            </div>
            <h2 className="text-xl font-bold text-[#141413]">Application Render Error</h2>
            <p className="text-xs text-[#696969] leading-relaxed">
              An unexpected display issue occurred in this section. The session remains authenticated.
            </p>
            {this.state.error?.message && (
              <div className="p-3 bg-[#F3F0EE] rounded-[16px] text-[11px] font-mono text-[#CF4500] text-left overflow-x-auto">
                {this.state.error.message}
              </div>
            )}
            <div className="flex gap-3 justify-center pt-2">
              <button
                onClick={() => {
                  this.setState({ hasError: false, error: null });
                  window.location.reload();
                }}
                className="mc-btn-primary text-xs py-2 px-5"
              >
                Reload Investigation Command
              </button>
              <button
                onClick={() => {
                  window.location.href = '/dashboard';
                }}
                className="mc-btn-secondary text-xs py-2 px-4"
              >
                Return to Dashboard
              </button>
            </div>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <ErrorBoundary>
      <QueryClientProvider client={queryClient}>
        <BrowserRouter>
          <AuthProvider>
            <App />
          </AuthProvider>
        </BrowserRouter>
      </QueryClientProvider>
    </ErrorBoundary>
  </React.StrictMode>
);
