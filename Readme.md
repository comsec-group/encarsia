# Encarsia: Evaluating CPU Fuzzers via Automatic Bug Injection
## Introduction
Welcome to the Encarsia artifacts repository! This, along with other repositories available at https://github.com/encarsia-artifacts or through our official artifact submission at https://doi.org/10.5281/zenodo.14664723, provides the resources needed to examine, reproduce, and extend our work. For additional information about Encarsia, please refer to the accompanying paper.

This is the sole README documenting Encarsia. Any other READMEs in our official artifact submission cover Encarsia's dependencies and are not intended to guide its usage. The README is organized as follows: First, we list all the available components of the artifacts, followed by a description of the survey. Next, we provide instructions for setting up the environment required to replicate the experiments. Finally, we outline the steps to re-run the experiments and describe the expected results.

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
- **Reproducible Evaluations**: To enable reproducible evaluations of DifuzzRTL, Processorfuzz, and Cascade on the EnCorpus bug set, we provide a Dockerfile for environment setup and dependency installation. We also make a pre-built Docker image available, which can be obtained as outlined in the Setup section. Additionally, we include Python scripts in the `fuzzers` directory at [encarsia-meta](https://github.com/encarsia-artifacts/encarsia-meta) to automate wrapping, environment variable configuration, and fuzzer execution against Encarsia-generated bugs. More details on how to reproduce our fuzzer evaluation are provided in the Setup, Usage, and Experiments sections below.

## Survey
The survey artifacts consist of two parts. First, the automatic collection of pull requests from GitHub and their subsequent automatic filtering in `survey/collecting`. The results are stored in survey/collecting/data.json. To see how to parse the data, refer to `survey/collecting/plot.py`. To reproduce the collection process, use `python survey/collecting/collect.py`. We recommend placing a GitHub personal access token in `survey/collecting/token` to avoid rate limits, which can cause significant delays.

Second, the results of the manual bug classification in `survey/classification/synthetic.json` and `survey/classification/natural.json`. To see how to parse the data, refer to `survey/classification/plot.py`.

## Setup
To simplify reproducing our experiments, we have prepared a fully self-contained evaluation setup based on Docker. To pull the pre-built Docker image run `make pull`. Alternatively, run `make build` to build the Docker image yourself. If you prefer not to use Docker, the Dockerfile is available as a reference for setting up a similar environment on a bare-metal system.

Since some experiments involve injecting thousands of bugs into large CPUs, the resulting files may total up to 1TB. We therefore recommend ensuring that the Docker root directory is configured to reside on a storage volume with sufficient capacity to handle these large file sizes.

Finally, to start a Docker container for running the experiments, use `make run`. Note the container ID displayed in the terminal output. You can use it later to restart and attach to the container for further experiments with `docker start <container_id> && docker attach <container_id>`.

## Usage
All of the functionality described in our paper, except the survey, is automated through a single Python script `encarsia.py` available at [encarsia-meta](https://github.com/encarsia-artifacts/encarsia-meta). The available features include:

1. Bug injection
2. Prefiltering of trivial bugs
3. Bug verification with Yosys
4. (Optional) Bug verification with JasperGold
5. Fuzzer evaluation

The script is flexible, allowing users to run experiments with various combinations of enabled features. For example, when Yosys verification and fuzzer evaluation are enabled, the script first verifies the bugs using Yosys, then proceeds to fuzzer evaluation with only the verified bugs. It also handles intermediate results, so if you run partial steps (e.g., only verification), the results are stored in an experiment directory and can be revisited later. To resume the experiment, specify the experiment directory with the `-d DIRECTORY` option, and the script will continue from where you left off. The experiment directory is structured as follows: 

```
experiment-directory/
├── <cpu_name>/                         # e.g., rocket, ibex
│   ├── inject_driver.log               # Example log generated by encarsia.py
│   ├── yosys_verify_script.tcl         # Example script generated by encarsia.py
│   |   .
│   |   .
│   ├── multiplexer/                    # Broken conditionals
│   ├── driver/                         # Signal Mix-ups
│   │   ├── 1/                          # Bug directory
│   │   │   ├── host.v                  # Buggy design source
│   │   │   |   .
│   │   │   |   .
│   │   │   └── <fuzzer>/               # e.g., cascade, processorfuzz
|   |   |       ├── fuzz.log            # Log of the fuzzer evaluation
|   |   |       ├── check_summary.log   # Result of the false positive filtering
|   |   |       |   . 
|   |   |       |   . 
```
At the top level, there is one directory for each cpu, such as Rocket or Ibex. Within each cpu directory are all the relevant cpu sources, scripts, and logs generated by encarsia.py, such as the logs from the bug injection. Each cpu directory also contains two subdirectories: one for Signal Mix-Ups (driver) and another for Broken Conditionals (multiplexer). These subdirectories store the bug directories, which contain all relevant files for each bug, such as the buggy cpu sources. Each bug directory also contains one subdirectory for each fuzzer, storing data such as the fuzzing logs. 

The script uses the following command syntax:
```
python encarsia.py [-h] [-d DIRECTORY] [-H HOSTS [HOSTS ...]] [-p PROCESSES] [-M MULTIPLEXER_BUGS [MULTIPLEXER_BUGS ...]] [-D DRIVER_BUGS [DRIVER_BUGS ...]] [-P] [-V] [-Y] [-F FUZZERS [FUZZERS ...]]
```
#### Arguments
- `-h` shows the help message.
- `-d DIRECTORY` sets the experiment directory path. If omitted, the script runs the entire process from scratch instead of reusing intermediate results.
- `-H HOSTS [HOSTS ...]` selects the CPUs for the experiments. Available CPU identifiers:
  - `ibex`: Ibex
  - `rocket`: Rocket
  - `boom`: BOOM
- `-p PROCESSES` specifies the number of processes for parallelizing experiments where applicable.

  **WARNING**: Experiments like Yosys bug verification and fuzzing with DifuzzRTL or ProcessorFuzz can use up to 32 GB of memory per process, so adjust the number of parallel processes accordingly.
- `-M MULTIPLEXER_BUGS [MULTIPLEXER_BUGS ...]` selects a subset of broken conditionals by bug directory name.
- `-D DRIVER_BUGS [DRIVER_BUGS ...]` selects a subset of signal mix-ups by bug directory name.
- `-P` enables filtering of trivial bugs.
- `-V` enables bug verification with JasperGold.
- `-Y` enables bug verification with Yosys.
- `-F FUZZERS [FUZZERS ...]` evaluates the specified fuzzers on selected bugs from the experiment directory. Available fuzzer identifiers:
  - `cascade`: Cascade
  - `difuzzrtl`: DifuzzRTL
  - `no_cov_difuzzrtl`: DifuzzRTL without coverage guidance
  - `processorfuzz`: ProcessorFuzz
  - `no_cov_processorfuzz`: ProcessorFuzz without coverage guidance


Next, we will detail the individual features and the files they generate.

### Bug injection
To inject the bugs, execute the following command in the `encarsia-meta/` directory:
```
python encarsia.py -d DIRECTORY -H HOSTS [HOSTS ...] -p PROCESSES
```

This will inject approximately 1000 Signal Mix-ups and 1000 Broken Conditionals per cpu, with slight deviations due to the inherent randomness of the injection. The final result of this step are the `host.v` files in each respective bug directory, as outlined in the previous section, containing the modified buggy cpu source code. The injection logs are located in the cpu directory, with `inject_multiplexer.log` for broken conditionals and `inject_driver.log` for signal mix-ups. A summary of the injection results, similar to Table 5 in the paper, is printed to the terminal.

Note that this step also initializes the experiment directory, so once bugs are injected into a cpu, rerunning the command in the same directory won't inject additional bugs. However, you can add more cpus to the same experiment directory.

### Prefiltering of trivial bugs
To filter out trivial bugs that render the cpu non-functional, use the `-P` option:
```
python encarsia.py -d DIRECTORY -H HOSTS [HOSTS ...] -p PROCESSES -P
```

This runs a single program on the cpu to check if it executes correctly, creating a prefilter directory in each bug directory. If `prefilter/fuzz.log` contains `Success`, the bug passes prefiltering. All other bugs are excluded from further steps.

### Bug verification using Yosys
To formally verify if the bugs are architecturally observable and thus suitable for fuzzer evaluation using the Yosys setup, use the `-Y` option:
```
python encarsia.py -d DIRECTORY -H HOSTS [HOSTS ...] -p PROCESSES -Y
```

This will generate `yosys_verify.log`, which contains the log of the verification in each bug directory. If successful, the verification will also produce `yosys_proof.S`, which is the sequence of instructions found by Yosys to trigger the bug and propagate it to an architecturally observable location. Any other bugs will be excluded from further steps. A summary of the verification results, similar to Table 6 in the paper, is printed to the terminal.

Note that EnCorpus was verified using our JasperGold setup, which is more robust and powerful. As a result, not all EnCorpus bugs will verify using Yosys. We discuss our JasperGold setup and the proof of architectural visibility, which we include with each EnCorpus bug, below.

### Bug verification using JasperGold (Optional)
The artifacts also include the initialization sequences, SystemVerilog assertions, and scripts for bug verification using JasperGold. However, due to licensing restrictions, we cannot include the applications required to run the JasperGold setup within the Docker container. If you have the necessary licenses, you can still run the experiment. We recommend setting up the environment bare metal by manually replicating the steps in the Dockerfile. Additionally, you'll need to update the `JASPER` variable in `defines.py` at [encarsia-meta](https://github.com/encarsia-artifacts/encarsia-meta) with the path to your JasperGold executable.

To formally verify if the bugs are architecturally observable and thus suitable for fuzzer evaluation using the JasperGold setup, use the `-V` option:
```
python encarsia.py -d DIRECTORY -H HOSTS [HOSTS ...] -p PROCESSES -V
```

This will generate `verify.log`, which contains the log of the verification in each bug directory. If successful, the verification will also produce `proof.vcd`, which is the input found by JasperGold to trigger the bug and propagate it to an architecturally observable location. The total verification runtime can be found under `Total time in state (seconds)` in `verify.log`. Since this experiment can't be easily reproduced by those without a JasperGold license, we include these files in the bug directories within EnCorpus, allowing users to verify that EnCorpus bugs are architecturally observable.

### Fuzzer Evaluation
To evaluate one or more fuzzers on the selected set of bugs, use the `-F` option with the corresponding fuzzer identifiers provided as `FUZZERS`:
```
python encarsia.py -d DIRECTORY -H HOSTS [HOSTS ...] -p PROCESSES -F FUZZERS [FUZZERS ...]
```

This will produce a corresponding fuzzer directory within each bug directory. `fuzzer.log` contains the log of the fuzzing run, but may include false positives, for example due to fuzzers making mistakes interpreting execution traces. `check_summary.log`, shows whether a bug was genuinely detected (DETECTED or NOT DETECTED) after filtering out those false positives. To determine the time to bug, refer to the timestamp at the first mismatch in fuzz.log. A summary of the fuzzing results, similar to Tables 7, 8, 9, and 10 in the paper, is printed to the terminal.

Note that bug directory names are remapped to 1-N in ascending order in the table. Here's an example for the Ibex Signal Mix-ups from EnCorpus:

| Paper    |  1 |  2  |  3  |  4  |  5  |  6  |  7  |  8  |  9  |  10 |  11 |  12 |  13 |  14 |  15  |
|----------|:--:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:----:|
| EnCorpus | 39 | 254 | 293 | 394 | 526 | 565 | 619 | 743 | 779 | 820 | 858 | 945 | 963 | 974 | 1198 |

To avoid long runtimes when reproducing the experiments, we have limited the fuzzing runtime to 30 minutes by default. The original 24-hour duration, which could take several days on systems with fewer cores. This should be sufficient to yield the same results as those presented in the paper. To modify the timeout, update `FUZZING_TIMEOUT` in `/encarsia-meta/defines.py` to your preferred value in seconds.

### Combination of steps
To execute a combination of steps in sequence, use the respective options together. For example, to prefilter and subsequently verify, run:
```
python encarsia.py -d DIRECTORY -H HOSTS [HOSTS ...] -p PROCESSES -P -Y
```

## Experiments
We provide an overview of the experiments presented in the paper, including the required computing resources (**Requirements**), execution steps (**Execution**), and expected results (**Results**).

### (E1) Injection (Section 7.1)
This experiment precisely replicates the injection experiment described in Section 7.1 of the paper.

#### Requirements
- **Human time:** 5 minutes
- **Compute time:** 20 minutes
- **Disk:** 100 GB
- **Memory:** 8 GB

#### Execution
Navigate to the `/encarsia-meta` directory and run:
```
python encarsia.py -d out/Injection -H ibex rocket -p 30
```
Optionally, include `boom` in the `-H` option to inject bugs into BOOM:
```
python encarsia.py -d out/Injection -H ibex rocket boom -p 30
```
Note that this requires up to 512 GB of additional disk space.

#### Results
This experiment injects around 1000 Signal Mix-ups and 1000 Broken Conditionals per CPU. The resulting host.v files and injection logs can be found in the experiment directory at `/encarsia-meta/out/Injection`. A summary of the injection results, similar to Table 5 in the paper, is printed to the terminal. We expect the summary table to closely match the one presented in the paper.

### (E2) Verification (Section 7.1)
This experiment closely follows the one in Section 7.1 of the paper, with the key difference being our use of a fully open-source verification setup based on Yosys. Additionally, we limit the experiment to bugs from the EnCorpus bug set to shorten the experiment time.

#### Requirements
- **Human time:** 5 minutes
- **Compute time:** 1 hour
- **Disk:** 6 GB
- **Memory:** device dependent
  - **Ibex** 4 GB per process
  - **Rocket** 8 GB per process
  - **BOOM** 32 GB per process

#### Execution
Navigate to the `/encarsia-meta` directory and run:
```
python encarsia.py -d out/EnCorpus -H ibex rocket boom -p 30 -Y
```

#### Results
This experiment generates formal proofs of architectural observability for the EnCorpus bugs using Yosys. The resulting `yosys_verify.log` and `yosys_proof.S` can be found in the EnCorpus experiment directory at `/encarsia-meta/out/EnCorpus`. A summary of the verification results, similar to Table 6 in the paper, is printed to the terminal. We expect Yosys to verify most of the EnCorpus bugs in the simpler CPUs (Ibex and Rocket) and a smaller subset in the more complex BOOM. Furthermore, we expect the average verification time per bug to be similar to the values reported in Table 6 of the paper.

### (E3) Granularity of differential fuzzing (Section 8.1)
This experiment closely matches the fuzzing experiment described in Section 8.1 of the paper, with the key difference being the reduced fuzzing time of 30 minutes.

#### Requirements
- **Human time:** 5 minutes
- **Compute time:** 10 hours
- **Disk:** 100 GB
- **Memory:** 4 GB per process

#### Execution
Navigate to the `/encarsia-meta` directory and run:
```
python encarsia.py -d out/EnCorpus -H rocket boom -p 30 -F no_cov_difuzzrtl no_cov_processorfuzz
```

#### Results
This experiment generates a fuzzing run log in `fuzz.log` and the bug detection results (after false positive filtering) in `check_summary.log` within the corresponding fuzzer directories at `/encarsia-meta/out/EnCorpus`. A summary of the fuzzing results, similar to Table 8 in the paper, is printed to the terminal.

We expect the results to align with those presented in the paper, except for Rocket Signal Mix-up 1 and BOOM Signal Mix-ups 9 and 14. These bugs are detected by both DifuzzRTL and Processorfuzz in the Docker setup, but remain undetected by both in the bare-metal setup used for the data presented in the paper despite several fuzzing re-runs. We hypothesize that this discrepancy may be due to differences in the versions of fuzzer dependencies, such as Spike or Verilator. However, the lack of clarity regarding the internal versions used by the fuzzers has made it difficult to pinpoint the cause. We are currently investigating and will update the artifacts once the issue is resolved.

### (E4) Coverage metrics (Section 8.2)
This experiment closely matches the fuzzing experiment described in Section 8.2 of the paper, with the key difference being the reduced fuzzing time of 30 minutes.

#### Requirements
- **Human time:** 5 minutes
- **Compute time:** 10 hours
- **Disk:** 100 GB
- **Memory:** 4 GB per process

#### Execution
Navigate to the `/encarsia-meta` directory and run:
```
python encarsia.py -d out/EnCorpus -H rocket boom -p 30 -F difuzzrtl processorfuzz
```

#### Results
This experiment generates a fuzzing run log in `fuzz.log` and the bug detection results (after false positive filtering) in `check_summary.log` within the corresponding fuzzer directories at `/encarsia-meta/out/EnCorpus`. A summary of the fuzzing results, similar to Table 9 in the paper, is printed to the terminal. Similarly, as in the previous experiment, we observe discrepancies between Docker and bare-metal setups for Rocket Signal Mix-up 1 and BOOM Signal Mix-ups 9 and 14.

### (E5) Importance of the seeds (Section 8.3)
This experiment closely matches the fuzzing experiment described in Section 8.3 of the paper, with the key difference being the reduced fuzzing time of 30 minutes.

#### Requirements
- **Human time:** 5 minutes
- **Compute time:** 90 minutes
- **Disk:** 10 GB
- **Memory:** 4 GB per process

Note that this experiment reuses the results of DifuzzRTL evaluation from experiment (E4) if available, hence the lower compute time and disk space requirements. If the results of experiment (E4) are not available, the requirements are approximately half that of experiment (E4).

#### Execution
Navigate to the `/encarsia-meta` directory and run:
```
python encarsia.py -d out/EnCorpus -H rocket boom -p 30 -F difuzzrtl cascade
```

#### Results
This experiment generates a fuzzing run log in `fuzz.log` and the bug detection results (after false positive filtering) in `check_summary.log` within the corresponding fuzzer directories at `/encarsia-meta/out/EnCorpus`. A summary of the fuzzing results, similar to Table 10 in the paper, is printed to the terminal. Similarly, as in the previous experiment, we observe discrepancies between Docker and bare-metal setups for Rocket Signal Mix-up 1 and BOOM Signal Mix-ups 9 and 14 on DifuzzRTL. The results for Cascade exactly match those reported in the paper.

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