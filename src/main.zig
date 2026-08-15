const r4os = @import("r4os");

const sample_origin = "LOGDIAG";
const sample_text = "LOGDIAG SDK application record";
const diagnostic_text = "LOGDIAG diagnostic snapshot";

pub fn r4_app_main(r4_app: *r4os.App) i32 {
    var ctx = r4_app.system();
    ctx.println("LOGDIAG");

    var ok = true;
    if (!ctx.hasFn("service_call")) return fail(&ctx, "service-api");
    if (!ensureRunning(&ctx)) return fail(&ctx, "start");

    var status_before = r4os.abi.LogServiceStatus{};
    if (ctx.logServiceStatus(&status_before) != r4os.abi.service_api_result_ok) return fail(&ctx, "status");
    if (status_before.source_count != @as(u32, @intCast(r4os.abi.log_service_source_count)) or status_before.record_capacity != @as(u32, @intCast(r4os.abi.log_service_max_records))) {
        return fail(&ctx, "status-shape");
    }
    printCheck(&ctx, "LOGSVC status", true);

    var sources_query = r4os.abi.LogServiceSourceQuery{};
    var sources = r4os.abi.LogServiceSourcePage{};
    if (ctx.logServiceSources(&sources_query, &sources) != r4os.abi.service_api_result_ok) return fail(&ctx, "sources");
    if (!hasSource(&sources, r4os.abi.log_service_source_bootlog) or
        !hasSource(&sources, r4os.abi.log_service_source_driver) or
        !hasSource(&sources, r4os.abi.log_service_source_protocol) or
        !hasSource(&sources, r4os.abi.log_service_source_application) or
        !hasSource(&sources, r4os.abi.log_service_source_service) or
        !hasSource(&sources, r4os.abi.log_service_source_console) or
        !hasSource(&sources, r4os.abi.log_service_source_diagnostic) or
        !hasSource(&sources, r4os.abi.log_service_source_file))
    {
        return fail(&ctx, "source-list");
    }
    printCheck(&ctx, "LOGSVC sources", true);

    if (ctx.logServiceWrite(r4os.abi.log_severity_info, sample_origin, sample_text) != r4os.abi.service_api_result_ok) return fail(&ctx, "write");

    var app_query = r4os.abi.LogServiceRecordQuery{
        .source_id = r4os.abi.log_service_source_application,
        .severity_min = r4os.abi.log_severity_info,
    };
    copyFixedZ(app_query.search[0..], sample_text);
    var app_records = r4os.abi.LogServiceRecordPage{};
    if (ctx.logServiceRecords(&app_query, &app_records) != r4os.abi.service_api_result_ok or app_records.count == 0) return fail(&ctx, "app-record");
    printCheck(&ctx, "LOGSVC app records", true);

    if (ctx.logServiceWriteRecord(r4os.abi.log_service_source_diagnostic, r4os.abi.log_record_type_diagnostic_snapshot, r4os.abi.log_severity_info, sample_origin, diagnostic_text) != r4os.abi.service_api_result_ok) return fail(&ctx, "diagnostic-write");

    var service_query = r4os.abi.LogServiceRecordQuery{
        .source_id = r4os.abi.log_service_source_service,
        .severity_min = r4os.abi.log_severity_debug,
    };
    copyFixedZ(service_query.search[0..], "TIMESVC");
    var service_records = r4os.abi.LogServiceRecordPage{};
    if (ctx.logServiceRecords(&service_query, &service_records) != r4os.abi.service_api_result_ok or service_records.total_matches == 0) return fail(&ctx, "service-records");

    var console_query = r4os.abi.LogServiceRecordQuery{
        .source_id = r4os.abi.log_service_source_console,
        .severity_min = r4os.abi.log_severity_debug,
    };
    var console_records = r4os.abi.LogServiceRecordPage{};
    if (ctx.logServiceRecords(&console_query, &console_records) != r4os.abi.service_api_result_ok or console_records.total_matches == 0) return fail(&ctx, "console-records");

    var diagnostic_query = r4os.abi.LogServiceRecordQuery{
        .source_id = r4os.abi.log_service_source_diagnostic,
        .severity_min = r4os.abi.log_severity_debug,
    };
    copyFixedZ(diagnostic_query.search[0..], diagnostic_text);
    var diagnostic_records = r4os.abi.LogServiceRecordPage{};
    if (ctx.logServiceRecords(&diagnostic_query, &diagnostic_records) != r4os.abi.service_api_result_ok or diagnostic_records.total_matches == 0) return fail(&ctx, "diagnostic-records");

    var file_query = r4os.abi.LogServiceRecordQuery{
        .source_id = r4os.abi.log_service_source_file,
        .severity_min = r4os.abi.log_severity_debug,
    };
    var file_records = r4os.abi.LogServiceRecordPage{};
    if (ctx.logServiceRecords(&file_query, &file_records) != r4os.abi.service_api_result_ok or file_records.total_matches == 0) return fail(&ctx, "file-records");
    printCheck(&ctx, "LOGSVC non-kernel records", true);

    var driver_query = r4os.abi.LogServiceRecordQuery{
        .source_id = r4os.abi.log_service_source_driver,
        .severity_min = r4os.abi.log_severity_debug,
    };
    var driver_records = r4os.abi.LogServiceRecordPage{};
    if (ctx.logServiceRecords(&driver_query, &driver_records) != r4os.abi.service_api_result_ok or driver_records.total_matches == 0) {
        ok = false;
        ctx.println("LOGSVC driver records missing");
    }

    var protocol_query = r4os.abi.LogServiceRecordQuery{
        .source_id = r4os.abi.log_service_source_protocol,
        .severity_min = r4os.abi.log_severity_debug,
    };
    var protocol_records = r4os.abi.LogServiceRecordPage{};
    if (ctx.logServiceRecords(&protocol_query, &protocol_records) != r4os.abi.service_api_result_ok or protocol_records.total_matches == 0) {
        ok = false;
        ctx.println("LOGSVC protocol records missing");
    }
    printCheck(&ctx, "LOGSVC R4D/R4P records", ok);

    var export_page = r4os.abi.LogServiceExportPage{};
    if (ctx.logServiceExport(&app_query, &export_page) != r4os.abi.service_api_result_ok or export_page.bytes == 0 or !contains(export_page.text[0..@as(usize, export_page.bytes)], sample_text)) {
        return fail(&ctx, "export");
    }
    printCheck(&ctx, "LOGSVC export", true);

    if (!testUnavailablePath(&ctx)) return fail(&ctx, "unavailable");
    printCheck(&ctx, "LOGSVC unavailable error", true);

    ctx.write("LOGDIAG result: ");
    ctx.println(if (ok) "OK" else "FAILED");
    return if (ok) 0 else 1;
}

fn ensureRunning(ctx: *const r4os.r4sys.Context) bool {
    var info: r4os.abi.ServiceInfo = .{};
    const status = ctx.serviceStatus(r4os.abi.log_r4x_service_name, &info);
    if (status != r4os.abi.service_api_result_ok) return false;
    if (info.state == r4os.abi.service_state_running) return waitOpen(ctx, 160);
    const start = ctx.serviceStart(r4os.abi.log_r4x_service_name, &info);
    if (start != r4os.abi.service_api_result_ok and start != r4os.abi.service_api_result_running) return false;
    return waitOpen(ctx, 160);
}

fn waitOpen(ctx: *const r4os.r4sys.Context, max_ticks: u32) bool {
    var tick: u32 = 0;
    while (tick < max_ticks) : (tick += 1) {
        var info: r4os.abi.ServiceInfo = .{};
        const rc = ctx.serviceOpen(r4os.abi.log_r4x_service_name, &info);
        if (rc == r4os.abi.service_api_result_ok and info.handle != 0) {
            _ = ctx.serviceClose(info.handle);
            return true;
        }
        ctx.sleepTicks(1);
    }
    return false;
}

fn testUnavailablePath(ctx: *const r4os.r4sys.Context) bool {
    var info: r4os.abi.ServiceInfo = .{};
    const stop = ctx.serviceStop(r4os.abi.log_r4x_service_name, &info, ctx.ticksFromMilliseconds(1000));
    if (stop != r4os.abi.service_api_result_ok) return false;

    var status = r4os.abi.LogServiceStatus{};
    const unavailable = ctx.logServiceStatus(&status);
    if (unavailable == r4os.abi.service_api_result_ok) return false;

    const start = ctx.serviceStart(r4os.abi.log_r4x_service_name, &info);
    if (start != r4os.abi.service_api_result_ok and start != r4os.abi.service_api_result_running) return false;
    return waitOpen(ctx, 160);
}

fn hasSource(page: *const r4os.abi.LogServiceSourcePage, source_id: u32) bool {
    var i: usize = 0;
    while (i < page.count and i < page.sources.len) : (i += 1) {
        if (page.sources[i].id == source_id) return true;
    }
    return false;
}

fn printCheck(ctx: *const r4os.r4sys.Context, label: []const u8, ok: bool) void {
    ctx.write("  ");
    ctx.write(label);
    ctx.write(": ");
    ctx.println(if (ok) "OK" else "FAILED");
}

fn fail(ctx: *const r4os.r4sys.Context, label: []const u8) i32 {
    ctx.write("LOGDIAG FAILED: ");
    ctx.println(label);
    return 1;
}

fn copyFixedZ(out: []u8, value: []const u8) void {
    @memset(out, 0);
    if (out.len == 0) return;
    const count = @min(value.len, out.len - 1);
    if (count > 0) @memcpy(out[0..count], value[0..count]);
}

fn contains(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        var j: usize = 0;
        while (j < needle.len and haystack[i + j] == needle[j]) : (j += 1) {}
        if (j == needle.len) return true;
    }
    return false;
}
