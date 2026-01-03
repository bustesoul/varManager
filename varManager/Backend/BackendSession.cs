using System;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using varManager.Properties;

namespace varManager.Backend
{
    public static class BackendSession
    {
        private static readonly SemaphoreSlim s_lock = new SemaphoreSlim(1, 1);
        private static BackendClient? s_client;
        private static BackendConfig? s_config;
        private static Process? s_process;
        private static string? s_baseUrl;

        public static BackendConfig? Config => s_config;

        public static async Task EnsureStartedAsync(Action<string>? log, CancellationToken ct)
        {
            await s_lock.WaitAsync(ct).ConfigureAwait(false);
            try
            {
                if (s_client == null || string.IsNullOrEmpty(s_baseUrl))
                {
                    s_baseUrl = ResolveBaseUrl();
                    s_client = new BackendClient(s_baseUrl);
                }

                if (await s_client.HealthAsync(ct).ConfigureAwait(false))
                {
                    await RefreshConfigAsync(log, ct).ConfigureAwait(false);
                    return;
                }

                StartProcess(log);

                var deadline = DateTime.UtcNow.AddSeconds(10);
                while (DateTime.UtcNow < deadline)
                {
                    if (await s_client.HealthAsync(ct).ConfigureAwait(false))
                    {
                        await RefreshConfigAsync(log, ct).ConfigureAwait(false);
                        return;
                    }
                    await Task.Delay(200, ct).ConfigureAwait(false);
                }

                throw new InvalidOperationException("后端启动超时");
            }
            finally
            {
                s_lock.Release();
            }
        }

        public static async Task<BackendJobResult> RunJobAsync(
            string kind,
            object? args,
            Action<string>? log,
            CancellationToken ct)
        {
            await EnsureStartedAsync(log, ct).ConfigureAwait(false);
            if (s_client == null)
            {
                throw new InvalidOperationException("后端未初始化");
            }

            var start = await s_client.StartJobAsync(kind, args, ct).ConfigureAwait(false);
            ulong id = start.Id;
            ulong? from = null;
            JobView job;

            while (true)
            {
                job = await s_client.GetJobAsync(id, ct).ConfigureAwait(false);
                var logs = await s_client.GetJobLogsAsync(id, from, ct).ConfigureAwait(false);
                if (logs.Dropped)
                {
                    log?.Invoke("后端日志已截断");
                }
                foreach (var line in logs.Lines)
                {
                    log?.Invoke(line);
                }
                from = logs.Next;

                if (string.Equals(job.Status, "succeeded", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(job.Status, "failed", StringComparison.OrdinalIgnoreCase))
                {
                    break;
                }

                await Task.Delay(300, ct).ConfigureAwait(false);
            }

            var finalLogs = await s_client.GetJobLogsAsync(id, from, ct).ConfigureAwait(false);
            if (finalLogs.Dropped)
            {
                log?.Invoke("后端日志已截断");
            }
            foreach (var line in finalLogs.Lines)
            {
                log?.Invoke(line);
            }

            JsonElement? result = null;
            if (job.ResultAvailable)
            {
                var jobResult = await s_client.GetJobResultAsync(id, ct).ConfigureAwait(false);
                result = jobResult.Result;
            }

            if (string.Equals(job.Status, "failed", StringComparison.OrdinalIgnoreCase))
            {
                if (!string.IsNullOrEmpty(job.Error))
                {
                    log?.Invoke($"error: {job.Error}");
                }
                else
                {
                    log?.Invoke($"error: 后端作业失败 ({kind})");
                }
            }

            return new BackendJobResult(job, result);
        }

        public static BackendJobResult RunJob(
            string kind,
            object? args,
            Action<string>? log,
            CancellationToken ct)
        {
            return RunJobAsync(kind, args, log, ct).GetAwaiter().GetResult();
        }

        public static async Task ShutdownAsync(Action<string>? log, CancellationToken ct)
        {
            BackendClient? client = s_client;
            Process? proc = s_process;

            if (client != null)
            {
                try
                {
                    await client.ShutdownAsync(ct).ConfigureAwait(false);
                }
                catch (Exception ex)
                {
                    log?.Invoke($"shutdown failed: {ex.Message}");
                }
            }

            if (proc != null && !proc.HasExited)
            {
                try
                {
                    if (!proc.WaitForExit(2000))
                    {
                        proc.Kill(true);
                    }
                }
                catch (Exception ex)
                {
                    log?.Invoke($"kill backend failed: {ex.Message}");
                }
            }
        }

        public static void ApplyConfigToSettings(BackendConfig config)
        {
            Settings.Default.varspath = config.Varspath ?? string.Empty;
            Settings.Default.vampath = config.Vampath ?? string.Empty;
            if (config.VamExec != null)
            {
                Settings.Default.defaultVamExec = config.VamExec;
            }
        }

        private static async Task RefreshConfigAsync(Action<string>? log, CancellationToken ct)
        {
            if (s_client == null)
            {
                return;
            }
            try
            {
                s_config = await s_client.GetConfigAsync(ct).ConfigureAwait(false);
                if (s_config != null)
                {
                    ApplyConfigToSettings(s_config);
                }
            }
            catch (Exception ex)
            {
                log?.Invoke($"读取后端配置失败: {ex.Message}");
            }
        }

        private static void StartProcess(Action<string>? log)
        {
            if (s_process != null && !s_process.HasExited)
            {
                return;
            }

            string exePath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "varManager_backend.exe");
            if (!File.Exists(exePath))
            {
                throw new FileNotFoundException($"后端程序不存在: {exePath}");
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = exePath,
                WorkingDirectory = AppDomain.CurrentDomain.BaseDirectory,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            s_process = Process.Start(startInfo);
            log?.Invoke("后端已启动");
        }

        private static string ResolveBaseUrl()
        {
            string host = "127.0.0.1";
            int port = 57123;
            string cfgPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "config.json");
            if (File.Exists(cfgPath))
            {
                try
                {
                    var json = File.ReadAllText(cfgPath);
                    using var doc = JsonDocument.Parse(json);
                    if (doc.RootElement.TryGetProperty("listen_host", out var hostProp))
                    {
                        var value = hostProp.GetString();
                        if (!string.IsNullOrWhiteSpace(value))
                        {
                            host = value;
                        }
                    }
                    if (doc.RootElement.TryGetProperty("listen_port", out var portProp))
                    {
                        if (portProp.ValueKind == JsonValueKind.Number && portProp.TryGetInt32(out var portValue))
                        {
                            port = portValue;
                        }
                    }
                }
                catch
                {
                    // ignore config parse errors; fallback to defaults
                }
            }
            return $"http://{host}:{port}/";
        }
    }
}
