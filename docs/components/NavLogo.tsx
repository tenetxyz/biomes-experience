export default function NavLogo() {
    return (
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: "0.25em",
          fontSize: "32px",
          textTransform: "uppercase",
        }}
      >
        <img
          src="/images/biomesAW_logo.png"
          style={{ height: "calc(var(--nextra-navbar-height) - 20px)" }}
          alt="Biomes AW"
        />
      </div>
    );
  }