The central star-core tap button — radial plasma-cyan gradient, dark ring, glow halo, and a 2.4s idle pulse (disabled under prefers-reduced-motion).

```jsx
<Core pressed={pressed} onPointerDown={tap} size={210}>
  {/* ripple ring + floating "+J" + quantum particles go here as children */}
</Core>
```

Drive `pressed` true briefly on tap (scale 0.96 + stronger glow). Render tap-feedback effects (expanding ripple, floating gain text, particles) as children positioned over it.
