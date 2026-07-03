---
name: rtos-design-audit
description: Audits embedded firmware and RTOS designs for multi-core bus contention, scheduling jitter, clock-step vulnerabilities, and buffer sizing limits.
---

# RTOS & Embedded Design Audit Guidelines

This skill provides a systematic framework for reviewing and auditing embedded firmware architectures (especially ESP32/FreeRTOS-based systems) before hardware layout and code implementation. It helps identify multi-core resource contention, timing discontinuities, and sampling jitter issues.

---

## 1. Audit Checkpoints

### Checkpoint A: Hardware Bus Topology & Concurrency Map
*   **Principle:** Physical communication buses (SPI, I2C, UART) cannot be accessed concurrently across different RTOS tasks or processor cores without dedicated hardware isolation or non-blocking synchronization.
*   **Audit Procedure:**
    1. Identify all tasks and the CPU cores they run on.
    2. Map out which tasks access which physical buses and GPIO pins.
    3. Ensure high-rate critical tasks (e.g., sensor sampling) do not share a physical bus with slow, blocking tasks (e.g., TFT display writes or file system reads).
    4. If sharing is unavoidable, verify that access is guarded by a mutex and that the worst-case lock duration does not violate the high-rate task's period.

### Checkpoint B: Worst-Case Execution Time (WCET) Budget
*   **Principle:** High-rate sensor acquisition tasks must execute in a strictly bounded, non-blocking duration.
*   **Audit Procedure:**
    1. Calculate the target sampling period (e.g., $1000 / 175 \text{ Hz} \approx 5.71 \text{ ms}$).
    2. Sum the maximum execution times of all synchronous operations inside the loop (e.g., register reads, memory copies, block writes).
    3. Verify that slow serial protocols (like I2C reads of secondary telemetry) are offloaded to lower-priority tasks on other cores. The sampling loop's WCET should consume less than **10%** of the overall sampling period.

### Checkpoint C: Clock & Time-Sync Integrity
*   **Principle:** Real-time waveform data must calculate its sampling rate and interval using monotonic hardware timers, and system wall-clock steps (like NTP updates) must be handled as explicit stream discontinuities.
*   **Audit Procedure:**
    1. Ensure sample rate (`fs`) and segment anchoring do not rely on wall-clock time (`nowMicros()`) for delta calculations.
    2. Use strictly monotonic microsecond clocks (like `esp_timer_get_time()`) for rate calculations.
    3. Monitor the delta between monotonic time and system time. If the difference jumps (e.g., $>100\text{ ms}$), immediately push a `CTRL_GAP` control marker to reset downstream decoders, restart the segment, and establish a new time anchor.

### Checkpoint D: Interrupt-Driven Acquisition
*   **Principle:** High-precision data acquisition must be hardware-paced via interrupts to eliminate software polling latency and RTOS tick jitter.
*   **Audit Procedure:**
    1. Ensure the task does not poll the sensor's Data Ready (DRDY) pin using active-sleep loops (such as `vTaskDelay(1)`).
    2. Configure a GPIO interrupt on the DRDY pin (e.g., falling edge) to handle pacing.
    3. Use FreeRTOS task notifications (`vTaskNotifyGiveFromISR` / `ulTaskNotifyTake`) to block the sampling task until the hardware asserts the data line.
    4. Include a safety timeout on the blocking call to recover from hardware lockups.

### Checkpoint E: Buffer Dimensioning & Network Resilience
*   **Principle:** RAM ring buffers must be sized to ride out the worst-case network recovery time, not based on arbitrary constants.
*   **Audit Procedure:**
    1. Define the worst-case network outage duration (e.g., 60 seconds for WiFi reconnection and MQTT handshake).
    2. Calculate required buffer size: $\text{Samples} = \text{Outage Duration (s)} \times \text{Sample Rate (Hz)}$.
    3. Verify that the target microcontroller has sufficient SRAM/PSRAM to allocate this buffer without exhausting memory.

---

## 2. Audit Report Template

When performing an audit, generate a markdown report containing the following details:

```markdown
# RTOS Design Audit: [Component Name]

## Concurrency Map
| Task Name | CPU Core | Bus Accessed | Pacing Method |
|---|---|---|---|
| | | | |

## Audit Results
- **Checkpoint A (Bus Concurrency):** [Pass/Fail & Details]
- **Checkpoint B (WCET Budget):** [Pass/Fail & Details]
- **Checkpoint C (Clock Integrity):** [Pass/Fail & Details]
- **Checkpoint D (Interrupt Pacing):** [Pass/Fail & Details]
- **Checkpoint E (Buffer Sizing):** [Pass/Fail & Details]

## Recommended Actions
1. [Action 1]
2. [Action 2]
```
