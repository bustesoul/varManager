using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;

namespace varManager.Backend
{
    public sealed class BackendClient
    {
        private readonly HttpClient _http;
        private readonly JsonSerializerOptions _jsonOptions;

        public BackendClient(string baseUrl)
        {
            _http = new HttpClient { BaseAddress = new Uri(baseUrl, UriKind.Absolute) };
            _jsonOptions = new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true,
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
            };
        }

        public async Task<bool> HealthAsync(CancellationToken ct)
        {
            try
            {
                using var resp = await _http.GetAsync("health", ct).ConfigureAwait(false);
                return resp.IsSuccessStatusCode;
            }
            catch
            {
                return false;
            }
        }

        public Task<BackendConfig> GetConfigAsync(CancellationToken ct)
        {
            return GetAsync<BackendConfig>("config", ct);
        }

        public Task<StartJobResponse> StartJobAsync(string kind, object? args, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(kind))
            {
                throw new ArgumentException("kind is required", nameof(kind));
            }
            var payload = new StartJobRequest { Kind = kind, Args = args };
            return PostAsync<StartJobResponse>("jobs", payload, ct);
        }

        public Task<JobView> GetJobAsync(ulong id, CancellationToken ct)
        {
            return GetAsync<JobView>($"jobs/{id}", ct);
        }

        public Task<JobLogsResponse> GetJobLogsAsync(ulong id, ulong? from, CancellationToken ct)
        {
            var url = from.HasValue ? $"jobs/{id}/logs?from={from.Value}" : $"jobs/{id}/logs";
            return GetAsync<JobLogsResponse>(url, ct);
        }

        public Task<JobResultResponse> GetJobResultAsync(ulong id, CancellationToken ct)
        {
            return GetAsync<JobResultResponse>($"jobs/{id}/result", ct);
        }

        public Task ShutdownAsync(CancellationToken ct)
        {
            return PostAsync("shutdown", new { }, ct);
        }

        private async Task<T> GetAsync<T>(string path, CancellationToken ct)
        {
            using var resp = await _http.GetAsync(path, ct).ConfigureAwait(false);
            var json = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode)
            {
                throw new InvalidOperationException($"backend error: {resp.StatusCode} {json}");
            }
            var result = JsonSerializer.Deserialize<T>(json, _jsonOptions);
            if (result == null)
            {
                throw new InvalidOperationException("backend response is empty");
            }
            return result;
        }

        private async Task<T> PostAsync<T>(string path, object? body, CancellationToken ct)
        {
            using var content = new StringContent(
                JsonSerializer.Serialize(body, _jsonOptions),
                Encoding.UTF8,
                "application/json");
            using var resp = await _http.PostAsync(path, content, ct).ConfigureAwait(false);
            var json = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode)
            {
                throw new InvalidOperationException($"backend error: {resp.StatusCode} {json}");
            }
            var result = JsonSerializer.Deserialize<T>(json, _jsonOptions);
            if (result == null)
            {
                throw new InvalidOperationException("backend response is empty");
            }
            return result;
        }

        private async Task PostAsync(string path, object? body, CancellationToken ct)
        {
            using var content = new StringContent(
                JsonSerializer.Serialize(body, _jsonOptions),
                Encoding.UTF8,
                "application/json");
            using var resp = await _http.PostAsync(path, content, ct).ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode)
            {
                var json = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
                throw new InvalidOperationException($"backend error: {resp.StatusCode} {json}");
            }
        }
    }

    public sealed class BackendConfig
    {
        [JsonPropertyName("listen_host")]
        public string? ListenHost { get; set; }
        [JsonPropertyName("listen_port")]
        public int ListenPort { get; set; }
        [JsonPropertyName("log_level")]
        public string? LogLevel { get; set; }
        [JsonPropertyName("job_concurrency")]
        public int JobConcurrency { get; set; }
        [JsonPropertyName("varspath")]
        public string? Varspath { get; set; }
        [JsonPropertyName("vampath")]
        public string? Vampath { get; set; }
        [JsonPropertyName("vam_exec")]
        public string? VamExec { get; set; }
        [JsonPropertyName("downloader_path")]
        public string? DownloaderPath { get; set; }
        [JsonPropertyName("downloader_save_path")]
        public string? DownloaderSavePath { get; set; }
    }

    public sealed class StartJobRequest
    {
        [JsonPropertyName("kind")]
        public string Kind { get; set; } = string.Empty;
        [JsonPropertyName("args")]
        public object? Args { get; set; }
    }

    public sealed class StartJobResponse
    {
        [JsonPropertyName("id")]
        public ulong Id { get; set; }
        [JsonPropertyName("status")]
        public string Status { get; set; } = string.Empty;
    }

    public sealed class JobView
    {
        [JsonPropertyName("id")]
        public ulong Id { get; set; }
        [JsonPropertyName("kind")]
        public string Kind { get; set; } = string.Empty;
        [JsonPropertyName("status")]
        public string Status { get; set; } = string.Empty;
        [JsonPropertyName("progress")]
        public int Progress { get; set; }
        [JsonPropertyName("message")]
        public string Message { get; set; } = string.Empty;
        [JsonPropertyName("error")]
        public string? Error { get; set; }
        [JsonPropertyName("log_offset")]
        public ulong LogOffset { get; set; }
        [JsonPropertyName("log_count")]
        public ulong LogCount { get; set; }
        [JsonPropertyName("result_available")]
        public bool ResultAvailable { get; set; }
    }

    public sealed class JobLogsResponse
    {
        [JsonPropertyName("id")]
        public ulong Id { get; set; }
        [JsonPropertyName("from")]
        public ulong From { get; set; }
        [JsonPropertyName("next")]
        public ulong Next { get; set; }
        [JsonPropertyName("dropped")]
        public bool Dropped { get; set; }
        [JsonPropertyName("lines")]
        public string[] Lines { get; set; } = Array.Empty<string>();
    }

    public sealed class JobResultResponse
    {
        [JsonPropertyName("id")]
        public ulong Id { get; set; }
        [JsonPropertyName("result")]
        public JsonElement Result { get; set; }
    }

    public sealed class BackendJobResult
    {
        public BackendJobResult(JobView job, JsonElement? result)
        {
            Job = job;
            Result = result;
        }

        public JobView Job { get; }
        public JsonElement? Result { get; }
        public bool Succeeded => string.Equals(Job.Status, "succeeded", StringComparison.OrdinalIgnoreCase);
    }
}
