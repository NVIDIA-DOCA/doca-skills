# Bundle JTBD coverage manifest

This file enumerates the JTBDs the doca-skills bundle CLAIMS to cover,
machine-derived from each class-shape prompt's `intent:` field under
`devops/runner/prompts/`. Class-shape prompts are designed (per AUTHORING
§ 1a + § 13) to each express ONE shape of job — so the prompt's intent
is the closest authoritative answer to "what jobs is this bundle built
to answer well?".

**Regenerate**:

```
bash devops/ci/jtbd-coverage/regenerate-bundle-coverage.sh
```

**Consumer**: [`devops/ci/check-jtbd-coverage.sh`](../check-jtbd-coverage.sh)
(SOFT WARN by default, promotable to HARD via `--strict`).

| Intent | Prompt | Audience | Baseline artifact |
| --- | --- | --- | --- |
| orientation | 01_orientation | beginner | (general) |
| first_app | 02_first_app | beginner | doca-flow |
| version_lookup | 03_latest_tag | anyone running docker | (general) |
| debug | 04_link_error_debug | intermediate | doca-flow |
| deploy_service | 05_deploy_doca_service | intermediate | doca-dms |
| verify_capability | 06_run_doca_tool | intermediate | doca-caps |
| configure_library_context | 07_setup_doca_library_context | intermediate | doca-rdma |
| configure_library_context | 08_set_up_doca_control_plane_channel | intermediate | doca-comch |
| configure_library_context | 09_offload_data_op_to_doca_accelerator | intermediate | doca-dma |
| configure_library_context | 10_configure_doca_queue_pair_for_line_rate_io | intermediate | doca-eth |
| wire_doca_into_non_cpu_compute | 11_wire_doca_into_gpu_compute | intermediate | doca-gpunetio |
| offload_cryptographic_operation | 12_offload_cryptographic_op_to_doca_accelerator | intermediate | doca-sha |
| introspect_host_from_dpu | 13_introspect_host_from_dpu | intermediate | doca-apsh |
| run_workload_on_doca_target_processor | 14_run_workload_on_doca_target_processor | intermediate | doca-dpa |
| offload_bulk_compression | 15_offload_bulk_compression_to_doca_accelerator | intermediate | doca-compress |
| offload_aead_encryption | 16_offload_aead_encryption_to_doca_accelerator | intermediate | doca-aes-gcm |
| implement_custom_congestion_control | 17_implement_custom_congestion_control | intermediate | doca-pcc |
| offload_erasure_coding | 18_offload_erasure_coding_to_doca_accelerator | intermediate | doca-erasure-coding |
| export_application_telemetry | 19_export_application_telemetry | intermediate | doca-telemetry-exporter |
| bridge_existing_dpdk_app_to_doca_libraries | 20_bridge_dpdk_app_to_doca_libraries | intermediate | doca-dpdk-bridge |
| configure_library_context | 21_stream_media_with_doca_rmax | intermediate | doca-rmax |
| add_stateful_layer_on_top_of_existing_dataplane | 22_add_stateful_connection_tracking_to_flow | intermediate | doca-flow |
| modify_sample_cli | 23_wire_doca_argp_into_app | intermediate | doca-argp |
| offload_storage_transport_to_doca | 25_offload_storage_transport_to_doca | intermediate | doca-sta |
| collect_telemetry_with_doca | 26_collect_telemetry_with_doca | intermediate | doca-telemetry |
| offload_remote_memory_ops_to_dpu | 28_offload_remote_memory_ops_to_dpu | intermediate | doca-urom |
| communicate_from_a_dpa_kernel | 29_communicate_from_a_dpa_kernel | intermediate | doca-dpa |
| do_rdma_from_a_dpa_kernel | 30_do_rdma_from_a_dpa_kernel | intermediate | doca-dpa |
| expose_emulated_pcie_device_from_dpu | 32_expose_emulated_pcie_device_from_dpu | intermediate | doca-devemu |
| deploy_service | 35_deploy_doca_time_sync_service | intermediate | doca-firefly |
| deploy_dataplane_debug_service | 37_deploy_doca_dataplane_debug_service | intermediate | doca-flow-inspector |
| deploy_hpc_offload_service | 40_deploy_doca_hpc_offload_service | intermediate | doca-urom-svc |
| deploy_service | 41_deploy_doca_runtime_security_service | intermediate | doca-argus |
| deploy_service | 43_deploy_a_doca_service_container_on_the_bluefield | intermediate | doca-container-deployment |
| run_micro_benchmark | 44_run_a_doca_library_micro_benchmark | intermediate | doca-bench |
| inspect_admin_tool_state | 45_inspect_a_doca_comm_channel | intermediate | doca-comm-channel-admin |
| inspect_pcc_counters_from_running_kernel | 51_inspect_pcc_counters | intermediate | doca-pcc-counters |
| bridge_socket_traffic_to_dpu | 52_relay_socket_traffic_to_the_dpu | intermediate | doca-socket-relay |
| apply_hardware_touching_change | 55_apply_a_hardware_touching_doca_change_safely | intermediate | doca-hardware-safety |
| establish_foundation_before_per_library_work | 56_establish_doca_runtime_foundation_for_an_app | intermediate | doca-common |
| decide_drop_down_and_port_libibverbs | 57_drop_to_low_level_verbs_below_doca_rdma | intermediate | doca-verbs |
| configure_library_context | 58_drive_rdma_from_accelerator | intermediate | doca-rdmi |
| configure_library_context | 59_drive_rdma_from_gpu_kernel | intermediate | doca-gpi |
| modify_device_state_safely | 60_manage_device_state_programmatically | intermediate | doca-mgmt |
| bridge_host_flow_into_dpa_inline_processing | 61_bridge_a_doca_flow_pipe_into_target_processor_inline | advanced | doca-flow-dpa-provider |
| deploy_and_validate_shipped_reference_algorithm_then_decide_keep_tune_replace | 62_deploy_and_validate_a_shipped_reference_congestion_control_algorithm | intermediate | doca-pcc-ztr-rttcc-algo |
| deploy_service | 63_deploy_doca_host_introspection_service | intermediate | doca-os-inspector |
| tune_flow_pipeline_end_to_end | 64_tune_a_doca_flow_pipeline | intermediate | doca-flow-tune |
| measure_dpa_offloaded_flow_performance | 65_measure_doca_flow_dpa_offload_performance | intermediate | doca-flow-dpa-perf |
| stand_up_remote_doca_flow_control_plane | 66_stand_up_doca_flow_grpc_server | intermediate | doca-flow-grpc-server |
| baseline_host_side_doca_flow_rule_rate | 67_baseline_doca_flow_pipeline_performance | intermediate | doca-flow-perf |
| author_and_wire_in_doca_bench_extension_end_to_end | 68_author_and_wire_in_a_doca_bench_extension | advanced | doca-bench-extension |
| author_custom_doca_bench_extension | 68_author_custom_doca_bench_extension | intermediate | doca-bench-extension |
| measure_gpu_initiated_rdma_write_latency | 69_measure_kernel_initiated_rdma_write_latency_on_gpu_nic_pair | intermediate | doca-gpi-ib-write-lat |
| measure_sustained_gpu_initiated_rdma_write_bw | 70_measure_sustained_rdma_write_bw_from_gpunetio_path | intermediate | doca-gpunetio-ib-write-bw |
| measure_gpu_initiated_rdma_write_latency_real_time | 71_measure_gpu_init_rdma_write_latency_jitter_from_gpunetio_for_real_time | intermediate | doca-gpunetio-ib-write-lat |
| wire_engine_into_openssl_pipeline | 72_wire_doca_sha_offload_engine_into_openssl_pipeline | intermediate | doca-sha-offload-engine |
| operate_host_side_tool | 73_produce_an_app_shield_host_os_profile | intermediate | doca-apsh-config |
| diagnose_dpa_correctness_with_tracing | 74_diagnose_a_dpa_kernel_with_high_level_tracer | advanced | doca-dpa-hl-tracer |
| evaluate_cc_algorithm_for_production | 75_evaluate_an_spcx_cc_algorithm_on_a_live_fabric | advanced | doca-spcx-cc |
| stand_up_doca_telemetry_exporter_pipeline_end_to_end | 76_stand_up_doca_telemetry_exporter_pipeline | intermediate | doca-telemetry-utils |
