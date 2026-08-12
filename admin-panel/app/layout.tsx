import React from 'react';
import './globals.css';

export default function Layout({children}:{children:React.ReactNode}) {
  return (
    <html lang="en">
      <body style={{margin:0,fontFamily:'system-ui',background:'#050816',color:'#f8fafc'}}>
        {children}
      </body>
    </html>
  );
}
