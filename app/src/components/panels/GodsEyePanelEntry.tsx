import { Component, type ErrorInfo, type ReactNode, lazy, Suspense } from "react";
import { ComputersPanelContent } from "./ComputersPanelContent";

const GodsEyePanelLazy = lazy(() => import("../../panels/godseye/GodsEyePanel"));

class GodsEyeErrorBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.warn("[GodsEye] panel failed", error, info.componentStack);
  }

  render() {
    if (this.state.failed) {
      return (
        <div>
          <p>WebGL globe unavailable — showing COMPUTERS roster.</p>
          <ComputersPanelContent />
        </div>
      );
    }
    return this.props.children;
  }
}

export function GodsEyePanelEntry() {
  return (
    <GodsEyeErrorBoundary>
      <Suspense fallback={<div>initialising globe…</div>}>
        <GodsEyePanelLazy />
      </Suspense>
    </GodsEyeErrorBoundary>
  );
}
