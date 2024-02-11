import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'
import './index.css'
import { ConnectProvider } from './context/ConnectContext.jsx'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <ConnectProvider>
    <App />
    </ConnectProvider>
  </React.StrictMode>,
)
