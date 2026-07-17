import AppKit
import BirdFlowCore
import BirdFlowMetal
import BirdFlowVisualization
import Foundation
import SwiftUI

@main
struct BirdFlowViewerApp: App {
  init() {
    if CommandLine.arguments.contains("--capture-formation-frames") {
      do {
        let arguments = try FormationFlightObservatoryCapture.Arguments(
          commandLine: CommandLine.arguments
        )
        try FormationFlightObservatoryCapture.run(arguments)
        Foundation.exit(EXIT_SUCCESS)
      } catch {
        FileHandle.standardError.write(
          Data("birdflow-viewer formation capture failed: \(error)\n".utf8)
        )
        Foundation.exit(EXIT_FAILURE)
      }
    } else if CommandLine.arguments.contains("--capture-readme-frames") {
      do {
        let arguments = try ReadmeShowcaseCapture.Arguments(
          commandLine: CommandLine.arguments
        )
        try ReadmeShowcaseCapture.run(arguments)
        Foundation.exit(EXIT_SUCCESS)
      } catch {
        FileHandle.standardError.write(
          Data("birdflow-viewer capture failed: \(error)\n".utf8)
        )
        Foundation.exit(EXIT_FAILURE)
      }
    }
    NSApplication.shared.setActivationPolicy(.regular)
    DispatchQueue.main.async {
      NSApplication.shared.activate(ignoringOtherApps: true)
    }
  }

  var body: some Scene {
    WindowGroup("BirdFlowMetal Viewer") {
      ViewerRootView()
        .frame(minWidth: 1120, minHeight: 720)
    }
    .windowStyle(.hiddenTitleBar)
    .commands {
      CommandGroup(replacing: .newItem) {}
    }
  }
}

@MainActor
private final class ViewerModel: ObservableObject {
  @Published private(set) var liveSimulation: LiveSimulation?
  @Published private(set) var renderer: MetalVisualizationRenderer?
  @Published private(set) var solverMetrics = LiveSimulationMetrics()
  @Published private(set) var renderMetrics = VisualizationMetrics()
  @Published private(set) var recorder: RunBundleRecorder?
  @Published var settings = VisualizationSettings() {
    didSet {
      renderer?.settings = settings
      renderer?.camera = settings.camera
      scheduleSettingsSave()
    }
  }
  @Published var errorMessage: String?
  @Published var showNewRun = false
  @Published var isCreatingRun = false

  @Published var freeFlight = false
  @Published var reynolds: Float = 2_000
  @Published var referenceSpeed: Float = 8
  @Published var latticeSpeed: Float = 0.04
  @Published var resolutionScale = 1
  @Published var batchSize = 32

  private var settingsSaveWork: DispatchWorkItem?

  func createDefaultRunIfNeeded() {
    guard liveSimulation == nil, !isCreatingRun else { return }
    createRun()
  }

  func createRun() {
    isCreatingRun = true
    let old = liveSimulation
    liveSimulation = nil
    renderer = nil
    old?.stop()

    do {
      let configuration = try makeConfiguration()
      let bird = BirdParameters.demonstration
      let center =
        configuration.domainOriginMeters
        + configuration.domainSizeMeters * 0.5
      let body = BirdBodyState(
        positionMeters: center,
        linearVelocityMetersPerSecond: freeFlight
          ? SIMD3<Float>(referenceSpeed, 0, 0)
          : .zero
      )
      let live = try LiveSimulation(
        configuration: configuration,
        bird: bird,
        initialBodyState: body,
        batchSize: batchSize
      )
      try install(live)
      recorder = nil
      showNewRun = false
      errorMessage = nil
    } catch {
      errorMessage = String(describing: error)
    }
    isCreatingRun = false
  }

  func resumeCheckpoint() {
    let panel = NSOpenPanel()
    panel.title = "Resume BirdFlow Checkpoint"
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }

    let old = liveSimulation
    liveSimulation = nil
    renderer = nil
    old?.stop()
    do {
      let live = try LiveSimulation(
        checkpointURL: url,
        batchSize: batchSize
      )
      try install(live)
      recorder = nil
      errorMessage = nil
    } catch {
      errorMessage = String(describing: error)
    }
  }

  func toggleRunning() {
    guard let liveSimulation else { return }
    if solverMetrics.running {
      liveSimulation.pause()
      solverMetrics.running = false
    } else {
      liveSimulation.start()
      solverMetrics.running = true
    }
  }

  func singleBatch() {
    liveSimulation?.advanceOneBatch()
  }

  func selectRunBundle() {
    guard let liveSimulation else { return }
    let panel = NSSavePanel()
    panel.title = "Record BirdFlow Run"
    panel.nameFieldStringValue = "BirdFlow-(Self.timestamp()).birdflowrun"
    panel.canCreateDirectories = true
    guard panel.runModal() == .OK, var url = panel.url else { return }
    if url.pathExtension != "birdflowrun" {
      url.appendPathExtension("birdflowrun")
    }
    do {
      let simulation = liveSimulation.simulation
      let newRecorder = try RunBundleRecorder(
        directory: url,
        configuration: simulation.configuration,
        bird: simulation.bird,
        deviceName: simulation.metalDevice.name
      )
      try newRecorder.save(settings: settingsForSave())
      recorder = newRecorder
      liveSimulation.setRecorder(newRecorder)
      errorMessage = nil
    } catch {
      errorMessage = String(describing: error)
    }
  }

  func stopRecording() {
    liveSimulation?.setRecorder(nil)
    recorder = nil
  }

  func saveDerivedKeyframe() {
    guard let recorder, let renderer else {
      errorMessage = "Choose a .birdflowrun bundle before saving a derived-field keyframe."
      return
    }
    renderer.requestDerivedFieldKeyframe(
      to: recorder.derivedURL(step: renderMetrics.displayedStep)
    )
  }

  func saveCheckpoint() {
    guard let liveSimulation else { return }
    if let recorder {
      liveSimulation.requestCheckpoint(
        to: recorder.checkpointURL(step: solverMetrics.step)
      )
      return
    }
    let panel = NSSavePanel()
    panel.title = "Save BirdFlow Checkpoint"
    panel.nameFieldStringValue = String(
      format: "step-%012llu.bfcp",
      solverMetrics.step
    )
    panel.canCreateDirectories = true
    guard panel.runModal() == .OK, var url = panel.url else { return }
    if url.pathExtension != "bfcp" { url.appendPathExtension("bfcp") }
    liveSimulation.requestCheckpoint(to: url)
  }

  private func install(_ live: LiveSimulation) throws {
    let newRenderer = try MetalVisualizationRenderer(liveSimulation: live)
    newRenderer.settings = settings
    newRenderer.camera = settings.camera
    live.setHandlers(
      metrics: { [weak self] metrics in
        Task { @MainActor [weak self] in self?.solverMetrics = metrics }
      },
      error: { [weak self] message in
        Task { @MainActor [weak self] in self?.errorMessage = message }
      }
    )
    newRenderer.setHandlers(
      metrics: { [weak self] metrics in
        Task { @MainActor [weak self] in
          guard let self else { return }
          self.renderMetrics = metrics
          var current = self.settings
          current.camera = newRenderer.camera
          if current.camera != self.settings.camera {
            self.settings = current
          }
        }
      },
      error: { [weak self] message in
        Task { @MainActor [weak self] in self?.errorMessage = message }
      }
    )
    liveSimulation = live
    renderer = newRenderer
    solverMetrics.step = live.simulation.stepIndex
    solverMetrics.timeSeconds = live.simulation.timeSeconds
    solverMetrics.running = false
  }

  private func makeConfiguration() throws -> SimulationConfiguration {
    let scale = max(1, resolutionScale)
    let grid = try GridSize(
      x: 96 * scale,
      y: 112 * scale,
      z: 96 * scale
    )
    let scaling = try LatticeScaling(
      characteristicLengthMeters: BirdParameters.demonstration.wingRootChordMeters,
      characteristicLengthCells: 12 * scale,
      referenceSpeedMetersPerSecond: referenceSpeed,
      targetReynoldsNumber: reynolds,
      physicalAirDensity: 1.225,
      latticeReferenceSpeed: latticeSpeed
    )
    return try SimulationConfiguration(
      grid: grid,
      domainOriginMeters: .zero,
      scaling: scaling,
      physicalAirDensity: 1.225,
      farFieldVelocityMetersPerSecond: freeFlight
        ? .zero
        : SIMD3<Float>(-referenceSpeed, 0, 0),
      spongeWidthCells: 8 * scale,
      spongeStrength: 0.06,
      freeFlight: freeFlight,
      fastMath: false
    )
  }

  private func settingsForSave() -> VisualizationSettings {
    var result = settings
    result.camera = renderer?.camera ?? settings.camera
    return result
  }

  private func scheduleSettingsSave() {
    settingsSaveWork?.cancel()
    guard let recorder else { return }
    let snapshot = settingsForSave()
    let work = DispatchWorkItem {
      try? recorder.save(settings: snapshot)
    }
    settingsSaveWork = work
    DispatchQueue.global(qos: .utility).asyncAfter(
      deadline: .now() + 0.35,
      execute: work
    )
  }

  private static func timestamp() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter.string(from: Date())
  }
}

private struct ViewerRootView: View {
  @StateObject private var model = ViewerModel()

  var body: some View {
    ZStack {
      Color(red: 0.012, green: 0.018, blue: 0.032)
        .ignoresSafeArea()
      HStack(spacing: 0) {
        viewer
        controls
          .frame(width: 310)
          .background(.ultraThinMaterial)
      }
    }
    .toolbar { toolbar }
    .sheet(isPresented: $model.showNewRun) {
      NewRunView(model: model)
    }
    .alert(
      "BirdFlow Viewer",
      isPresented: Binding(
        get: { model.errorMessage != nil },
        set: { if !$0 { model.errorMessage = nil } }
      )
    ) {
      Button("OK") { model.errorMessage = nil }
    } message: {
      Text(model.errorMessage ?? "")
    }
    .task { model.createDefaultRunIfNeeded() }
  }

  @ViewBuilder
  private var viewer: some View {
    ZStack(alignment: .topLeading) {
      if let renderer = model.renderer {
        MetalCanvas(renderer: renderer)
          .id(ObjectIdentifier(renderer))
      } else {
        ProgressView("Preparing Metal solver and viewer…")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .foregroundStyle(.secondary)
      }
      VStack(alignment: .leading, spacing: 4) {
        Text(
          "step \(model.renderMetrics.displayedStep)  •  \(model.solverMetrics.timeSeconds, format: .number.precision(.fractionLength(5))) s"
        )
        Text(
          "solver \(model.solverMetrics.solverStepsPerSecond, format: .number.precision(.fractionLength(1))) step/s  •  render \(model.renderMetrics.renderFPS, format: .number.precision(.fractionLength(0))) fps"
        )
        Text(
          "viewer GPU \(model.renderMetrics.rendererGPUTimeMilliseconds, format: .number.precision(.fractionLength(2))) ms  •  age \(model.renderMetrics.frameAgeMilliseconds, format: .number.precision(.fractionLength(1))) ms  •  dropped \(model.solverMetrics.droppedFieldFrames)"
        )
        if model.renderMetrics.qSurfaceOverflow {
          Text("Q surface suppressed: raise threshold or capacity")
            .foregroundStyle(.red)
        }
      }
      .font(.system(.caption, design: .monospaced))
      .padding(10)
      .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 8))
      .padding(12)
    }
  }

  private var controls: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 15) {
        GroupBox("Pressure surface") {
          Toggle("Show pressure", isOn: $model.settings.showPressureSurface)
          Picker("Units", selection: $model.settings.pressureUnit) {
            ForEach(PressureUnit.allCases, id: \.rawValue) {
              Text($0.rawValue).tag($0)
            }
          }
          slider(
            "Probe offset", value: $model.settings.pressureProbeOffsetCells, range: 0.5...4,
            suffix: "dx")
          if model.settings.pressureUnit == .pascals {
            slider(
              "Symmetric range", value: $model.settings.pressureRangePascals, range: 1...600,
              suffix: "Pa")
          } else {
            slider(
              "Symmetric range", value: $model.settings.pressureRangeCoefficient, range: 0.01...3,
              suffix: "Cp")
          }
          Toggle("Lock range", isOn: $model.settings.pressureRangeLocked)
          Text(
            "legend ±\(model.renderMetrics.pressureLegendRange, format: .number.precision(.fractionLength(3))) • sample max \(model.renderMetrics.pressureRangePascals, format: .number.precision(.fractionLength(3))) \(model.settings.pressureUnit.rawValue)"
          )
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
        }

        GroupBox("Flow slice") {
          Toggle("Show slice", isOn: $model.settings.showSlice)
          Picker("Field", selection: $model.settings.sliceField) {
            ForEach(SliceField.allCases, id: \.rawValue) { Text($0.title).tag($0) }
          }
          Picker("Plane", selection: $model.settings.sliceSnap) {
            ForEach(SliceSnap.allCases, id: \.rawValue) { Text($0.rawValue).tag($0) }
          }
          slider("Position", value: $model.settings.slicePosition, range: 0...1)
          if model.settings.sliceSnap == .oblique {
            slider(
              "Yaw", value: $model.settings.sliceYawRadians, range: -.pi ... .pi, suffix: "rad")
            slider(
              "Pitch", value: $model.settings.slicePitchRadians, range: -1.5...1.5, suffix: "rad")
          }
          slider("Opacity", value: $model.settings.sliceOpacity, range: 0...1)
          slider("Legend max", value: $model.settings.sliceRange, range: 0.1...250)
          Toggle("Velocity glyphs", isOn: $model.settings.showVelocityGlyphs)
          if let probe = model.renderMetrics.sliceProbe {
            Text(
              "probe \(probe.scalar, format: .number.precision(.fractionLength(3))) • |u| \(vectorLength(probe.velocityMetersPerSecond), format: .number.precision(.fractionLength(3))) m/s • |ω| \(vectorLength(probe.vorticityPerSecond), format: .number.precision(.fractionLength(2))) s⁻¹"
            )
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
          }
        }

        GroupBox("Pathline ribbons") {
          Toggle("Show ribbons", isOn: $model.settings.showRibbons)
          Picker("Color", selection: $model.settings.ribbonColor) {
            ForEach(RibbonColorField.allCases, id: \.rawValue) {
              Text($0.rawValue).tag($0)
            }
          }
          slider("Color range", value: $model.settings.ribbonColorRange, range: 0.1...250)
          slider(
            "Width", value: $model.settings.ribbonWidthMeters, range: 0.0002...0.012, suffix: "m")
          Stepper(
            "Seeds \(model.settings.tracerCount)", value: $model.settings.tracerCount, in: 16...512,
            step: 16)
          Stepper(
            "History \(model.settings.tracerHistory)", value: $model.settings.tracerHistory,
            in: 16...128, step: 8)
        }

        GroupBox("Q criterion — verified diagnostic") {
          Toggle("Show Q isosurface", isOn: $model.settings.showQCriterion)
          Picker("Color", selection: $model.settings.qColor) {
            ForEach(QSurfaceColorField.allCases, id: \.rawValue) {
              Text($0.rawValue).tag($0)
            }
          }
          slider("Threshold", value: $model.settings.qThreshold, range: 0.1...2_000, suffix: "s⁻²")
          Text(
            "90th positive-Q percentile \(model.renderMetrics.qSuggestedThreshold, format: .number.precision(.fractionLength(2))) s⁻²"
          )
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
          slider("Opacity", value: $model.settings.qOpacity, range: 0.05...1)
          Toggle("Clip with slice plane", isOn: $model.settings.clipQBySlicePlane)
          Stepper(
            "Capacity \(model.settings.qTriangleCapacity / 1_000)k triangles",
            value: $model.settings.qTriangleCapacity, in: 100_000...2_000_000, step: 100_000)
        }

        GroupBox("Persistence") {
          HStack {
            Button(model.recorder == nil ? "Choose run bundle…" : "Stop recording") {
              model.recorder == nil ? model.selectRunBundle() : model.stopRecording()
            }
            Spacer()
            Circle()
              .fill(model.recorder == nil ? Color.secondary : Color.red)
              .frame(width: 8, height: 8)
          }
          HStack {
            Button("Derived keyframe") { model.saveDerivedKeyframe() }
            Button("Checkpoint") { model.saveCheckpoint() }
          }
        }
      }
      .padding(14)
    }
  }

  @ToolbarContentBuilder
  private var toolbar: some ToolbarContent {
    ToolbarItemGroup {
      Button("New Run") { model.showNewRun = true }
      Button("Resume…") { model.resumeCheckpoint() }
      Divider()
      Button(model.solverMetrics.running ? "Pause" : "Run") {
        model.toggleRunning()
      }
      .keyboardShortcut(.space, modifiers: [])
      Button("Single Batch") { model.singleBatch() }
      Button("Reset") { model.createRun() }
    }
  }

  private func slider(
    _ title: String,
    value: Binding<Float>,
    range: ClosedRange<Float>,
    suffix: String = ""
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text(title)
        Spacer()
        Text("\(value.wrappedValue, format: .number.precision(.fractionLength(2))) \(suffix)")
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      Slider(value: value, in: range)
    }
    .font(.caption)
  }
}

private struct NewRunView: View {
  @ObservedObject var model: ViewerModel

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      Text("New BirdFlow Run")
        .font(.title2.weight(.semibold))
      Form {
        Toggle("Free six-degree-of-freedom flight", isOn: $model.freeFlight)
        LabeledContent("Reynolds number") {
          TextField("Re", value: $model.reynolds, format: .number)
            .frame(width: 100)
        }
        LabeledContent("Reference speed (m/s)") {
          TextField("m/s", value: $model.referenceSpeed, format: .number)
            .frame(width: 100)
        }
        LabeledContent("Lattice speed") {
          TextField("u lattice", value: $model.latticeSpeed, format: .number)
            .frame(width: 100)
        }
        Stepper(
          "Resolution scale: \(model.resolutionScale)×", value: $model.resolutionScale, in: 1...4)
        Stepper("Solver batch: \(model.batchSize) steps", value: $model.batchSize, in: 1...128)
      }
      HStack {
        Spacer()
        Button("Cancel") { model.showNewRun = false }
        Button("Create Run") { model.createRun() }
          .keyboardShortcut(.defaultAction)
          .disabled(model.isCreatingRun)
      }
    }
    .padding(24)
    .frame(width: 480)
  }
}

private struct MetalCanvas: NSViewRepresentable {
  let renderer: MetalVisualizationRenderer

  func makeNSView(context: Context) -> BirdFlowMTKView {
    let view = BirdFlowMTKView(frame: .zero, device: renderer.liveSimulation.simulation.metalDevice)
    view.birdFlowRenderer = renderer
    do {
      try renderer.configure(view)
    } catch {
      assertionFailure("Unable to configure BirdFlow renderer: \(error)")
    }
    return view
  }

  func updateNSView(_ view: BirdFlowMTKView, context: Context) {
    view.birdFlowRenderer = renderer
  }
}
