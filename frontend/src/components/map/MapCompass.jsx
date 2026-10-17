import React from 'react';

/**
 * Tactical Surveillance Compass
 * Displays real-time map orientation, cardinal directions (N, E, S, W),
 * degrees azimuth readout, and interactive click-to-reset True North.
 * 
 * @param {number} bearing - Current map bearing in degrees
 * @param {function} onResetNorth - Optional callback to reset map bearing to 0° True North
 * @param {string} className - Optional positioning / styling classes
 * @param {boolean} interactive - Whether clicking resets the orientation
 * @param {string} title - Accessible title / tooltip
 */
export const MapCompass = ({
  bearing = 0,
  onResetNorth,
  className = '',
  interactive = true,
  title = 'Compass Orientation'
}) => {
  // Normalize bearing to 0 - 360 range
  const normalized = ((bearing % 360) + 360) % 360;
  const degrees = Math.round(normalized);

  // Determine 8-point cardinal direction
  const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  const cardinalIndex = Math.round(normalized / 45) % 8;
  const cardinal = directions[cardinalIndex];

  const formattedBearing = `${degrees.toString().padStart(3, '0')}° ${cardinal}`;
  const isOffNorth = degrees !== 0 && degrees !== 360;

  const handleClick = (e) => {
    e.stopPropagation();
    if (interactive && onResetNorth) {
      onResetNorth();
    }
  };

  return (
    <div
      onClick={handleClick}
      title={isOffNorth && onResetNorth ? 'Click to reset to True North' : title}
      className={`group flex flex-col items-center select-none ${
        interactive && onResetNorth ? 'cursor-pointer' : 'cursor-default'
      } ${className}`}
    >
      <div className="relative flex flex-col items-center bg-[#141413]/90 hover:bg-[#141413] backdrop-blur-md px-2.5 py-2 rounded-2xl border border-white/15 hover:border-[#CF4500]/50 shadow-2xl transition-all duration-200 group-hover:scale-105 active:scale-95">
        
        {/* Tactical Compass Rose SVG */}
        <div className="relative w-12 h-12 flex items-center justify-center">
          <svg viewBox="0 0 64 64" className="w-full h-full">
            <defs>
              <radialGradient id="compassDialBg" cx="50%" cy="50%" r="50%">
                <stop offset="0%" stopColor="#1E293B" stopOpacity="0.8" />
                <stop offset="100%" stopColor="#0F172A" stopOpacity="0.95" />
              </radialGradient>
              <linearGradient id="northNeedleGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stopColor="#FF6B35" />
                <stop offset="100%" stopColor="#CF4500" />
              </linearGradient>
              <linearGradient id="southNeedleGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stopColor="#94A3B8" />
                <stop offset="100%" stopColor="#475569" />
              </linearGradient>
            </defs>

            {/* Bezel Ring */}
            <circle cx="32" cy="32" r="30" fill="url(#compassDialBg)" stroke="#334155" strokeWidth="1.5" />
            <circle cx="32" cy="32" r="28" fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="1" strokeDasharray="2 3" />

            {/* Static Cardinal Markers on Bezel */}
            {/* North Indicator */}
            <text x="32" y="10" textAnchor="middle" fill="#CF4500" fontSize="8" fontWeight="900" fontFamily="sans-serif">
              N
            </text>
            {/* East Indicator */}
            <text x="56" y="34.5" textAnchor="middle" fill="rgba(255,255,255,0.45)" fontSize="7" fontWeight="700" fontFamily="sans-serif">
              E
            </text>
            {/* South Indicator */}
            <text x="32" y="58" textAnchor="middle" fill="rgba(255,255,255,0.45)" fontSize="7" fontWeight="700" fontFamily="sans-serif">
              S
            </text>
            {/* West Indicator */}
            <text x="8" y="34.5" textAnchor="middle" fill="rgba(255,255,255,0.45)" fontSize="7" fontWeight="700" fontFamily="sans-serif">
              W
            </text>

            {/* Subtle Crosshair Lines */}
            <line x1="32" y1="13" x2="32" y2="23" stroke="rgba(255,255,255,0.15)" strokeWidth="0.8" />
            <line x1="32" y1="41" x2="32" y2="51" stroke="rgba(255,255,255,0.15)" strokeWidth="0.8" />
            <line x1="13" y1="32" x2="23" y2="32" stroke="rgba(255,255,255,0.15)" strokeWidth="0.8" />
            <line x1="41" y1="32" x2="51" y2="32" stroke="rgba(255,255,255,0.15)" strokeWidth="0.8" />

            {/* Dynamic Rotating Compass Needle */}
            {/* In aviation & GIS HUDs, the needle rotates to always point toward physical North */}
            <g
              style={{
                transform: `rotate(${-bearing}deg)`,
                transformOrigin: '32px 32px',
                transition: 'transform 0.15s cubic-bezier(0.2, 0, 0, 1)'
              }}
            >
              {/* North Pointer (Orange) */}
              <polygon points="32,12 36,32 32,29 28,32" fill="url(#northNeedleGrad)" filter="drop-shadow(0 1px 2px rgba(207,69,0,0.5))" />
              {/* North Pointer Left Wing Highlight */}
              <polygon points="32,12 28,32 32,29" fill="#FF8C5A" />

              {/* South Pointer (Silver/Slate) */}
              <polygon points="32,52 36,32 32,35 28,32" fill="url(#southNeedleGrad)" />
              {/* South Pointer Right Wing Shadow */}
              <polygon points="32,52 36,32 32,35" fill="#334155" />

              {/* Central Pivot Hub */}
              <circle cx="32" cy="32" r="4.5" fill="#0B0F19" stroke="#E2E8F0" strokeWidth="1.2" />
              <circle cx="32" cy="32" r="2" fill="#CF4500" />
            </g>
          </svg>

          {/* Glowing Ping when oriented directly North */}
          {!isOffNorth && (
            <span className="absolute top-0 right-0 w-2 h-2 rounded-full bg-[#10B981] ring-2 ring-[#0B0F19] animate-pulse"></span>
          )}
        </div>

        {/* Digital Heading Readout */}
        <div className="mt-1 flex items-center justify-center">
          <span className="text-[10px] font-mono font-bold tracking-wider text-white/90 bg-white/10 px-1.5 py-0.5 rounded-md border border-white/10">
            {formattedBearing}
          </span>
        </div>

        {/* Reset North prompt if off-axis */}
        {isOffNorth && onResetNorth && (
          <div className="mt-1 text-[8px] font-mono font-bold text-[#CF4500] uppercase tracking-wider scale-90">
            RESET N
          </div>
        )}
      </div>
    </div>
  );
};
