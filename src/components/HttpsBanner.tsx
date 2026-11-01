import React from 'react';
import { Lock, ExternalLink } from 'lucide-react';

export const HttpsBanner: React.FC = () => {
  if (typeof window === 'undefined') return null;

  const isSecure = window.isSecureContext;
  const isHttp = window.location.protocol === 'http:';

  if (isSecure && !isHttp) return null;

  const httpsUrl = window.location.href.replace('http:', 'https:');

  return (
    <aside 
      aria-label="Security and protocol warning"
      onClick={() => { window.location.href = httpsUrl; }}
      className="bg-amber-500/15 border-b border-amber-500/30 px-3 py-2 text-xs font-sans text-amber-200 flex items-center justify-between cursor-pointer active:bg-amber-500/25 transition-colors z-40 shrink-0"
    >
      <div className="flex items-center space-x-2 min-w-0">
        <Lock className="w-3.5 h-3.5 text-amber-400 shrink-0" />
        <span className="truncate text-[11px] sm:text-xs">
          HTTPS required for Android BLE — open <span className="underline font-mono font-semibold">{httpsUrl.replace('https://', '')}</span>
        </span>
      </div>
      <div className="flex items-center space-x-1 pl-2 text-[11px] font-semibold text-amber-300 shrink-0">
        <span>Switch</span>
        <ExternalLink className="w-3 h-3" />
      </div>
    </aside>
  );
};
