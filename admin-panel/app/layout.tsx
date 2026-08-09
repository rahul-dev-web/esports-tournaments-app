import React from 'react';
import './globals.css';

export default function Layout({children}:{children:React.ReactNode}) {
  return (
    <html lang="en">
      <body style={{margin:0,fontFamily:'system-ui',background:'#f7f7fb'}}>
        {children}
      </body>
    </html>
  );
}
