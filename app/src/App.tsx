import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { useEffect } from "react";
import { SplashPage } from "./pages/SplashPage";
import { StagingPage } from "./pages/StagingPage";
import { CockpitShell } from "./components/CockpitShell";
import { loadTheme, applyTheme } from "./lib/theme";
import "./styles/tokens.css";
import "./styles/themes/fieldset-dark.css";
import "./styles/themes/ghui-cyan.css";
import "./styles/themes/high-contrast.css";
import "./styles/density.css";
import "./index.css";

const queryClient = new QueryClient();

function ThemeBootstrap() {
  useEffect(() => {
    applyTheme(loadTheme());
  }, []);
  return null;
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeBootstrap />
      <BrowserRouter>
        <Routes>
          <Route path="/" element={<SplashPage />} />
          <Route path="/splash" element={<SplashPage />} />
          <Route path="/splash/staging" element={<StagingPage />} />
          <Route path="/workspace" element={<CockpitShell />} />
          <Route path="*" element={<Navigate to="/splash" replace />} />
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  );
}

export default App;
