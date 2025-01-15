# Encarsia: Evaluating CPU Fuzzers with Automatic Bug Injection
## Introduction
Welcome to the Encarsia artifacts repository! This, along with other repositories available at https://github.com/encarsia-artifacts or through our official artifact submission, provides the resources needed to examine, reproduce, and extend our work. For additional information about Encarsia, please refer to the accompanying paper.

This README is organized as follows: First, we list all the available components of the artifacts, followed by a description of the survey. Next, we provide instructions for setting up the environment required to replicate the experiments. Finally, we outline the steps to re-run the experiments and describe the expected results.

## Components
The artifacts include the following components, organized as indicated below:

- **Survey Results**: The results from our survey of naturally occurring bugs in RISC-V CPUs and manually injected bugs as part of the HACK@EVENT competition series are available in the `survey/` directory within this repository.
- **Encarsia**: Our custom-developed bug injection and verification tool, includes:
  - Bug injection netlist transformation passes, located in the `passes/inject/` directory at [encarsia-yosys](https://github.com/encarsia-artifacts/encarsia-yosys).
  - Scripts for running all Encarsia tools, available at [encarsia-meta](https://github.com/encarsia-artifacts/encarsia-meta).
- **Encarsia Verification Setups**: Two versions of Encarsia's verification setup are provided:
  - A proprietary setup based on JasperGold (to the extent permitted by our license agreements), located in the `jasper/` directory of [encarsia-meta](https://github.com/encarsia-artifacts/encarsia-meta).
  - An open-source setup based on Yosys, available in `passes/inject/verify_miter.cc` at [encarsia-yosys](https://github.com/encarsia-artifacts/encarsia-yosys).
- **EnCorpus**: The EnCorpus set of CPU bugs is provided in the following archives within this repository:
  - `EnCorpus_boom.tar.gz`
  - `EnCorpus_ibex.tar.gz`
  - `EnCorpus_rocket.tar.gz`
  
  These archives can be unpacked to `out/EnCorpus` using `make unpack_encorpus`.
- **Reproducible Evaluations**: Evaluations of DifuzzRTL, Processorfuzz, and Cascade against the bug set are detailed in the Setup and Experiments sections below.

## Survey
The survey artifacts consist of two parts. First, the automatic collection of pull requests from GitHub and their subsequent automatic filtering in `survey/collecting`. The results are stored in survey/collecting/data.json. To see how to parse the data, refer to `survey/collecting/plot.py`. To reproduce the collection process, use `survey/collecting/collect.py`. We recommend placing a GitHub personal access token in `survey/collecting/token` to avoid rate limits, which can cause significant delays.

Second, the results of the manual bug classification in `survey/classification/manually_assembled.json` and `survey/classification/natural.json`. To see how to parse the data, refer to `survey/classification/plot.py`.

## Setup
To simplify the setup for reproducing our experiments, we’ve prepared a Docker image. If you are willing to use the Docker image, you can obtain it with `make pull`. If you prefer not to use Docker, the Dockerfile is available as a reference for setting up a similar environment on a bare-metal system.

Since some experiments involve injecting thousands of bugs into large CPUs, the resulting files may total up to 3TB. We therefore recommend binding a directory of sufficient capacity to the Docker container. The Makefile handles this, just set `OUT_DIRECTORY` in the Makefile to your preferred path.

The EnCorpus bug set used in some experiments is compressed into multiple archives. To automatically extract it to `$(OUT_DIRECTORY)/EnCorpus`, run `make unpack_encorpus`.

Finally, to start a Docker container for running the experiments, use `make run`. More details on the experiments are provided below.

## Experiments
All experiments described in our paper, excluding the survey, are automated through a single Python script `encarsia.py` available at [encarsia-meta](https://github.com/encarsia-artifacts/encarsia-meta). The available experiments include:

1. Bug injection
2. Prefiltering of trivial bugs
3. Bug verification with Yosys
4. (Optional) Bug verification with JasperGold
5. Fuzzer evaluation

The script is flexible, allowing users to run experiments with varying combinations of enabled features. For example, when Yosys verification and fuzzer evaluation are enabled, the script first verifies the bugs using Yosys, then proceeds to fuzzer evaluation with only the verified bugs. It also handles intermediate results, so if you run partial steps (e.g., only verification), the results are stored in an experiment directory and can be revisited later. You can resume the experiment by specifying the directory with the -d DIRECTORY option, and the script will continue from where you left off. The experiment directory is structured as follows: 

```
experiment-directory/
├── <cpu_name>/              # e.g., rocket, ibex
│   ├── inject_driver.log       # Example log generated by encarsia.py
│   |   .
│   |   .
│   ├── multiplexer/            # Broken conditionals
│   ├── driver/                 # Signal Mix-ups
│   │   ├── 1/                  # Bug directory
│   │   │   ├── host.rtlil      # Buggy design source
│   │   │   |   .
│   │   │   |   .
│   │   │   └── <fuzzer>/       # e.g., cascade, processorfuzz
|   |   |       ├── fuzz.log    # Log of the fuzzer evaluation
|   |   |       |   . 
|   |   |       |   . 
```
At the top level, there is one directory for each cpu, such as Rocket or Ibex. Within each cpu directory are all the relevant cpu sources, scripts, and logs generated by encarsia.py, such as the logs from the bug injection. Each cpu directory also contains two subdirectories: one for Signal Mix-Ups (driver) and another for Broken Conditionals (multiplexer). These subdirectories store the bug directories, which contain all relevant files for each bug, such as the buggy cpu sources. Each bug directory also contains one subdirectory for each fuzzer, storing data such as the fuzzing logs. Next, we will detail the individual steps, the files they generate, and the expected outcomes.

### Bug injection
To inject the bugs, execute the following command in the `encarsia-meta/` directory `python encarsia.py -d DIRECTORY -H HOSTS [HOSTS ...] -p PROCESSES`, where:
- `DIRECTORY` specifies the path for the experiment directory.
- `HOSTS` specifies the cpus into which bugs will be injected.
- `PROCESSES` specifies the number of processes used to parallelize the injection where applicable.

WARNING: Experiments like Yosys bug verification and fuzzing with DifuzzRTL or ProcessorFuzz can use up to 16 GB of memory per process, so adjust the number of parallel processes accordingly.

This process will inject approximately 1000 Signal Mix-ups and 1000 Broken Conditionals per cpu, with slight deviations due to the inherent randomness of the injection. The final result of this step are the `host.v` files in each respective buggy directory, as outlined in the previous section, containing the modified buggy cpu source code. To determine the time spent injecting the bugs, refer to the timestamps printed at the beginning and end of inject_multiplexer.log and inject_driver.log located in the cpu directory. Note that this step initializes the experiment directory, so once bugs are injected into a cpu, rerunning the command in the same directory won't inject additional bugs. However, you can add more cpus to the same experiment directory.
### Prefiltering of trivial bugs
To avoid evaluating trivial bugs that render the cpu non-functional, use the -P option:
`python encarsia.py -d DIRECTORY -H HOSTS [HOSTS ...] -p PROCESSES -P`

This runs a single program on the cpu to check if it executes correctly, creating a prefilter directory in each bug directory. If `prefilter/fuzz.log` contains `Success`, the bug passes prefiltering. All other bugs are excluded from further steps.

### Bug verification using Yosys
To verify if the bugs are architectural and suitable for fuzzer evaluation using the Yosys setup, use the -Y option:
`python encarsia.py -d DIRECTORY -H HOSTS [HOSTS ...] -p PROCESSES -Y`

This will generate `yosys_verify.log`, which contains the log of the verification in each bug directory. If successful, the verification will also produce `yosys_proof.S`, which is the sequence of instructions found by Yosys to trigger the bug and propagate it to an architecturally observable location. Any other bugs will be excluded from further steps. To determine the time spent verifying a bug, check the timestamps printed at the beginning and end of `yosys_verify.log`.

Note that EnCorpus was verified using our JasperGold setup, which is more robust and powerful. As a result, not all EnCorpus bugs will verify using Yosys. We discuss our JasperGold setup and the proof of architectural visibility, which we include with each EnCorpus bug, below.

### Bug verification using JasperGold (Optional)
The artifacts also include the initialization sequences, SystemVerilog assertions, and scripts for bug verification using JasperGold. However, due to licensing restrictions, we cannot include the applications required to run the JasperGold setup within the Docker container. If you have the necessary licenses, you can still run the experiment. We recommend setting up the environment bare metal by manually replicating the steps in the Dockerfile. Additionally, you'll need to update the `JASPER` variable in `defines.py` at [encarsia-meta](https://github.com/encarsia-artifacts/encarsia-meta) with the path to your JasperGold executable.

To verify if the bugs are architectural and suitable for fuzzer evaluation using the JasperGold setup, use the -V option:
`python encarsia.py -d DIRECTORY -H HOSTS [HOSTS ...] -p PROCESSES -V`

This will generate `verify.log`, which contains the log of the verification in each bug directory. If successful, the verification will also produce `proof.vcd`, which is the input found by JasperGold to trigger the bug and propagate it to an architecturally observable location. The total verification runtime can be found under `Total time in state (seconds)` in `verify.log`. Since this experiment can't be easily reproduced by those without a JasperGold license, we include these files in the bug directories within EnCorpus, allowing users to verify that EnCorpus bugs are architecturally observable.

### Fuzzer Evaluation
To evaluate one or more fuzzers on the selected set of bugs, use the -F option with the corresponding fuzzer identifiers provided as `FUZZERS`:
`python encarsia.py -d DIRECTORY -H HOSTS [HOSTS ...] -p PROCESSES -F FUZZERS [FUZZERS ...]`

The available fuzzer identifiers are:
- **cascade**: Cascade
- **difuzzrtl**: DifuzzRTL
- **no_cov_difuzzrtl**: DifuzzRTL without coverage guidance
- **processorfuzz**: ProcessorFuzz
- **no_cov_processorfuzz**: ProcessorFuzz without coverage guidance

This will produce a corresponding fuzzer directory within each bug directory. `fuzzer.log` contains the log of the fuzzing run, but may include false positives, for example due to fuzzers making mistakes interpreting execution traces. `check_summary.log`, shows whether a bug was genuinely detected (DETECTED or NOT DETECTED) after filtering out those false positives. To determine the time to bug, refer to the timestamp at the first mismatch in fuzz.log.

To avoid long runtimes when reproducing the experiments, we have limited the fuzzing runtime to 30 minutes, compared to the original 24-hour duration, which could take several days on systems with fewer cores. This should be sufficient to yield the same results as those presented in the paper. To modify the timeout, update `FUZZING_TIMEOUT` in `/encarsia-meta/defines.py` to your preferred value in seconds.

To reproduce the results in Figures 5, 6, 7, and 9, run the appropriate fuzzers on the EnCorpus bug set. Note that bug IDs are remapped to 1-15 in ascending order in the paper. Here's an example for the Ibex Signal Mix-ups:

| Paper    |  1 |  2  |  3  |  4  |  5  |  6  |  7  |  8  |  9  |  10 |  11 |  12 |  13 |  14 |  15  |
|----------|:--:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:----:|
| EnCorpus | 39 | 254 | 293 | 394 | 526 | 565 | 619 | 743 | 779 | 820 | 858 | 945 | 963 | 974 | 1198 |

Please note that the results for Rocket Signal Mix-up 1 in the Docker setup differ from expectations. The bug is detected by both DifuzzRTL and Processorfuzz, but remains undetected by both in the bare-metal setup used for the data presented in the paper. We hypothesize that this discrepancy may be due to differences in the versions of fuzzer dependencies, such as Spike or Verilator. However, the lack of clarity regarding the internal versions used by the fuzzers has made it difficult to pinpoint the cause. We are currently investigating and will update the artifacts once the issue is resolved.

### Combination of steps
To execute a combination of steps in sequence, use the respective options together. For example, to prefilter and subsequently verify, run:
`python encarsia.py -d DIRECTORY -H HOSTS [HOSTS ...] -p PROCESSES -P -Y`

## Extending support for additional CPUs
Encarsia can be easily extended to support additional CPUs by creating a new `EncarsiaConfig` instance in `encarsia-meta/config.py` and adding a case for the CPU identifier in `get_host_config(name: str)` to return the new instance. Existing configurations can be used as a helpful reference.

To enable the following functionalities, the corresponding variables must be set in `EncarsiaConfig`:

#### 1. Bug Injection
- `reference_sources`: CPU source files
- `host_module`: top-level module for bug injection

#### 2. Bug Verification (using Yosys)
- `sensitization_cycles`: maximum number of cycles to trigger the bug
- `propagation_cycles`: maximum number of cycles to propagate the bug to an architecturally observable signal or register
- `timeout`: maximum duration (in seconds) for verification
- `observables`: list of architecturally observable signals or registers
- `sets`: used to assign specific values to signals
- `instruction_signal`: signal used to monitor the instructions supplied to the CPU

#### 3. Fuzzer Evaluation
- `cascade_receptor_sources`, `difuzzrtl_receptor_sources`, `processorfuzz_receptor_sources`: additional wrapper source files to enable fuzzing of the CPU using Cascade, DifuzzRTL, and ProcessorFuzz
- `cascade_directory`: path to the Cascade design repository
- `cascade_executable`: name of the Verilator executable generated by Cascade
- `difuzzrtl_toplevel`: top-level wrapper module for DifuzzRTL/ProcessorFuzz

Enabling the fuzzers to support additional CPUs may require further changes to the fuzzers themselves.