import SwiftUI

struct HUDOverlay: View {
    let snapshot: GameSnapshot
    let selectedBlueprint: BuildingKind?
    let onSelectBuild: (BuildingKind) -> Void
    let onStart: () -> Void
    let onRestart: () -> Void
    let onUpgrade: () -> Void

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .top) {
                VStack(spacing: 14) {
                    topBar
                    Spacer()
                    bottomBuildBar
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                if let alertText = snapshot.alertText {
                    Text(alertText)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.72, green: 0.28, blue: 0.16), Color(red: 0.22, green: 0.10, blue: 0.10)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .padding(.top, 78)
                }

                if let selected = snapshot.selectedBuilding {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            selectionPanel(selected)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }

                if snapshot.phase != .playing {
                    phaseOverlay
                }
            }
        }
        .allowsHitTesting(true)
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 14) {
            HStack(spacing: 10) {
                ForEach(ResourceKind.allCases) { resource in
                    resourceChip(resource)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                Text(waveTitle)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text(baseHealthTitle)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color(red: 0.94, green: 0.86, blue: 0.76))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(panelBackground)
        }
    }

    private var bottomBuildBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(GameConfig.buildMenu) { kind in
                    let entry = GameConfig.catalog(for: kind)
                    Button {
                        onSelectBuild(kind)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(entry.name)
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Circle()
                                    .fill(accent(for: kind))
                                    .frame(width: 10, height: 10)
                            }

                            Text(entry.description)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.75))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)

                            Text(entry.buildCost.compactDescription())
                                .font(.system(.caption, design: .monospaced, weight: .semibold))
                                .foregroundStyle(snapshot.stockpile.canAfford(entry.buildCost) ? Color.white.opacity(0.85) : Color(red: 0.98, green: 0.72, blue: 0.58))
                        }
                        .frame(width: 178, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(selectedBlueprint == kind ? accent(for: kind).opacity(0.5) : Color(red: 0.08, green: 0.12, blue: 0.17).opacity(0.9))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(selectedBlueprint == kind ? accent(for: kind) : Color.white.opacity(0.08), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
        .padding(10)
        .background(panelBackground)
    }

    private func selectionPanel(_ selected: SelectedBuildingSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selected.title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Mk \(selected.level)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.66))
                }

                Spacer()

                Circle()
                    .fill(statusAccent(for: selected.statusSeverity))
                    .frame(width: 11, height: 11)
            }

            Text(selected.subtitle)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.7))

            Text(selected.healthText)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Color(red: 0.95, green: 0.87, blue: 0.75))

            Text(selected.statusText)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(statusAccent(for: selected.statusSeverity))

            Divider()
                .overlay(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 6) {
                ForEach(selected.inventoryLines, id: \.self) { line in
                    Text(line)
                        .font(.system(.caption, design: .monospaced, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.82))
                }
            }

            if let cost = selected.upgradeCostText {
                Button(action: onUpgrade) {
                    HStack {
                        Text(selected.canUpgrade ? "Upgrade" : "Upgrade Locked")
                        Spacer()
                        Text(cost)
                            .font(.system(.caption, design: .monospaced, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selected.canUpgrade ? Color(red: 0.18, green: 0.42, blue: 0.32) : Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!selected.canUpgrade)
                .foregroundStyle(.white)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
            }
        }
        .padding(18)
        .frame(width: 260, alignment: .leading)
        .background(panelBackground)
    }

    private var phaseOverlay: some View {
        VStack(spacing: 16) {
            Text(phaseTitle)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text(phaseMessage)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            VStack(alignment: .leading, spacing: 6) {
                Text("1. Extend the network with depots.")
                Text("2. Mine ore, smelt alloy, forge ammo.")
                Text("3. Gun towers need ammo. Cannons need ammo plus energy.")
            }
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .foregroundStyle(Color(red: 0.94, green: 0.84, blue: 0.70))

            Button(snapshot.phase == .ready ? "Launch Colony" : "Restart Mission") {
                if snapshot.phase == .ready {
                    onStart()
                } else {
                    onRestart()
                }
            }
            .buttonStyle(.plain)
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.16, green: 0.48, blue: 0.44), Color(red: 0.72, green: 0.34, blue: 0.16)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.05, green: 0.09, blue: 0.13).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
                )
        )
    }

    private func resourceChip(_ resource: ResourceKind) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(resource.displayName)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.7))

            Text("\(snapshot.stockpile[resource])")
                .font(.system(.headline, design: .monospaced, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent(for: resource).opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(accent(for: resource).opacity(0.7), lineWidth: 1)
                )
        )
    }

    private var waveTitle: String {
        if let activeWaveNumber = snapshot.activeWaveNumber {
            return "Wave \(activeWaveNumber) / \(snapshot.totalWaves)"
        }

        if snapshot.phase == .ready {
            return "Wave 1 / \(snapshot.totalWaves)"
        }

        if snapshot.phase == .won {
            return "Mission Complete"
        }

        let nextWave = min(snapshot.completedWaves + 1, snapshot.totalWaves)
        let countdown = snapshot.countdown.map { Int($0.rounded(.up)) } ?? 0
        return countdown > 0 ? "Wave \(nextWave) in \(countdown)s" : "Wave \(nextWave) / \(snapshot.totalWaves)"
    }

    private var baseHealthTitle: String {
        "Base \(Int(snapshot.baseHealth))/\(Int(snapshot.baseMaxHealth))"
    }

    private var phaseTitle: String {
        switch snapshot.phase {
        case .ready:
            return "FortChain"
        case .won:
            return "Base Secure"
        case .lost:
            return "Base Lost"
        case .playing:
            return ""
        }
    }

    private var phaseMessage: String {
        switch snapshot.phase {
        case .ready:
            return "Defenses only hold if your logistics do. Build a chain from ore to alloy to ammo before the waves escalate."
        case .won:
            return "The colony held through the siege. Your network stayed alive long enough for every wave to break."
        case .lost:
            return "The base core fell after the supply line buckled. Rebuild the chain and try a sturdier layout."
        case .playing:
            return ""
        }
    }

    private var panelBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.11, blue: 0.16).opacity(0.92),
                Color(red: 0.10, green: 0.08, blue: 0.12).opacity(0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func accent(for kind: BuildingKind) -> Color {
        switch kind {
        case .core:
            return Color(red: 0.16, green: 0.65, blue: 0.67)
        case .depot:
            return Color(red: 0.28, green: 0.54, blue: 0.76)
        case .generator:
            return Color(red: 0.90, green: 0.78, blue: 0.28)
        case .mine:
            return Color(red: 0.82, green: 0.52, blue: 0.22)
        case .smelter:
            return Color(red: 0.86, green: 0.40, blue: 0.22)
        case .ammoFactory:
            return Color(red: 0.78, green: 0.34, blue: 0.22)
        case .gunTower:
            return Color(red: 0.28, green: 0.74, blue: 0.64)
        case .cannonTower:
            return Color(red: 0.94, green: 0.56, blue: 0.18)
        }
    }

    private func accent(for resource: ResourceKind) -> Color {
        switch resource {
        case .ore:
            return Color(red: 0.84, green: 0.56, blue: 0.26)
        case .alloy:
            return Color(red: 0.76, green: 0.82, blue: 0.90)
        case .energy:
            return Color(red: 0.98, green: 0.84, blue: 0.32)
        case .ammo:
            return Color(red: 0.96, green: 0.52, blue: 0.26)
        }
    }

    private func statusAccent(for severity: StatusSeverity) -> Color {
        switch severity {
        case .stable:
            return Color(red: 0.48, green: 0.88, blue: 0.66)
        case .warning:
            return Color(red: 0.98, green: 0.82, blue: 0.30)
        case .critical:
            return Color(red: 0.96, green: 0.40, blue: 0.30)
        }
    }
}
