import { useEffect, useRef, useState } from 'react';
import './Chart.css';

interface DataPoint {
  timestamp: number;
  values: Record<string, number>;
}

interface ChartSeries {
  key: string;
  label: string;
  color: string;
}

interface ChartProps {
  series: ChartSeries[];
  maxPoints?: number;
  height?: number;
  refreshInterval?: number;
  getData: () => Record<string, number>;
}

export function Chart({ 
  series, 
  maxPoints = 60, 
  height = 200,
  refreshInterval = 3000,
  getData 
}: ChartProps) {
  const [history, setHistory] = useState<DataPoint[]>([]);
  const containerRef = useRef<HTMLDivElement>(null);
  const [dimensions, setDimensions] = useState({ width: 400, height });

  // Update dimensions on resize
  useEffect(() => {
    const updateDimensions = () => {
      if (containerRef.current) {
        setDimensions({
          width: containerRef.current.clientWidth,
          height,
        });
      }
    };

    updateDimensions();
    window.addEventListener('resize', updateDimensions);
    return () => window.removeEventListener('resize', updateDimensions);
  }, [height]);

  // Collect data points
  useEffect(() => {
    const collectData = () => {
      const values = getData();
      setHistory(prev => {
        const newHistory = [...prev, { timestamp: Date.now(), values }];
        if (newHistory.length > maxPoints) {
          return newHistory.slice(-maxPoints);
        }
        return newHistory;
      });
    };

    // Collect initial data
    collectData();

    const interval = setInterval(collectData, refreshInterval);
    return () => clearInterval(interval);
  }, [getData, maxPoints, refreshInterval]);

  const padding = { top: 20, right: 20, bottom: 30, left: 45 };
  const chartWidth = dimensions.width - padding.left - padding.right;
  const chartHeight = dimensions.height - padding.top - padding.bottom;

  // Generate path for each series
  const generatePath = (seriesKey: string): string => {
    if (history.length < 2) return '';

    const points = history.map((point, index) => {
      const x = padding.left + (index / (maxPoints - 1)) * chartWidth;
      const y = padding.top + chartHeight - (point.values[seriesKey] / 100) * chartHeight;
      return `${x},${y}`;
    });

    return `M ${points.join(' L ')}`;
  };

  // Generate area fill path
  const generateAreaPath = (seriesKey: string): string => {
    if (history.length < 2) return '';

    const linePath = generatePath(seriesKey);
    if (!linePath) return '';

    const firstX = padding.left + (0 / (maxPoints - 1)) * chartWidth;
    const lastX = padding.left + ((history.length - 1) / (maxPoints - 1)) * chartWidth;
    const bottomY = padding.top + chartHeight;

    return `${linePath} L ${lastX},${bottomY} L ${firstX},${bottomY} Z`;
  };

  // Y-axis labels
  const yLabels = [0, 25, 50, 75, 100];

  // Get latest values
  const latestValues = history.length > 0 ? history[history.length - 1].values : {};

  return (
    <div className="chart" ref={containerRef}>
      <svg width={dimensions.width} height={dimensions.height}>
        {/* Grid lines */}
        <g className="chart__grid">
          {yLabels.map(value => {
            const y = padding.top + chartHeight - (value / 100) * chartHeight;
            return (
              <g key={value}>
                <line
                  x1={padding.left}
                  y1={y}
                  x2={dimensions.width - padding.right}
                  y2={y}
                  className="chart__grid-line"
                />
                <text
                  x={padding.left - 8}
                  y={y}
                  className="chart__axis-label"
                  textAnchor="end"
                  dominantBaseline="middle"
                >
                  {value}%
                </text>
              </g>
            );
          })}
        </g>

        {/* Area fills */}
        {series.map(s => (
          <path
            key={`area-${s.key}`}
            d={generateAreaPath(s.key)}
            fill={s.color}
            fillOpacity={0.1}
            className="chart__area"
          />
        ))}

        {/* Lines */}
        {series.map(s => (
          <path
            key={`line-${s.key}`}
            d={generatePath(s.key)}
            stroke={s.color}
            strokeWidth={2}
            fill="none"
            className="chart__line"
          />
        ))}

        {/* Current value dots */}
        {history.length > 0 && series.map(s => {
          const x = padding.left + ((history.length - 1) / (maxPoints - 1)) * chartWidth;
          const y = padding.top + chartHeight - (latestValues[s.key] / 100) * chartHeight;
          return (
            <circle
              key={`dot-${s.key}`}
              cx={x}
              cy={y}
              r={4}
              fill={s.color}
              className="chart__dot"
            />
          );
        })}
      </svg>

      {/* Legend */}
      <div className="chart__legend">
        {series.map(s => (
          <div key={s.key} className="chart__legend-item">
            <span 
              className="chart__legend-color" 
              style={{ backgroundColor: s.color }}
            />
            <span className="chart__legend-label">{s.label}</span>
            <span className="chart__legend-value" style={{ color: s.color }}>
              {latestValues[s.key]?.toFixed(1) ?? 0}%
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

