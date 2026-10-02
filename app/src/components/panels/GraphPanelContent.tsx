import { useEffect, useRef } from "react";
import uPlot from "uplot";
import "uplot/dist/uPlot.min.css";
import styles from "../../panels/GraphPanel.module.css";

const SERIES: uPlot.AlignedData = [
  new Float64Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]),
  new Float64Array([12, 14, 11, 16, 18, 15, 20, 22, 19, 24, 26, 23]),
  new Float64Array([8, 9, 10, 9, 11, 12, 11, 13, 14, 13, 15, 16]),
];

export function GraphPanelContent() {
  const hostRef = useRef<HTMLDivElement>(null);
  const plotRef = useRef<uPlot | null>(null);

  useEffect(() => {
    const host = hostRef.current;
    if (!host) return;

    const opts: uPlot.Options = {
      width: host.clientWidth,
      height: host.clientHeight,
      series: [{}, { stroke: "var(--cockpit-chrome)" }, { stroke: "var(--cockpit-active)" }],
      axes: [
        { stroke: "var(--cockpit-muted)" },
        { stroke: "var(--cockpit-muted)" },
      ],
    };

    plotRef.current = new uPlot(opts, SERIES, host);

    const ro = new ResizeObserver(() => {
      const p = plotRef.current;
      if (!p || !hostRef.current) return;
      p.setSize({ width: hostRef.current.clientWidth, height: hostRef.current.clientHeight });
    });
    ro.observe(host);

    return () => {
      ro.disconnect();
      plotRef.current?.destroy();
      plotRef.current = null;
    };
  }, []);

  return (
    <div className={styles.root}>
      <div className={styles.legend}>ResizeObserver · uPlot · agent latency bands</div>
      <div ref={hostRef} className={styles.chart} />
    </div>
  );
}
