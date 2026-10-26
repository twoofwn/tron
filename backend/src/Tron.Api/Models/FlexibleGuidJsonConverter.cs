using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Tron.Api.Models;

public class FlexibleGuidJsonConverter : JsonConverter<Guid>
{
    public override Guid Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
    {
        if (reader.TokenType == JsonTokenType.String)
        {
            var stringValue = reader.GetString();
            if (string.IsNullOrWhiteSpace(stringValue))
            {
                return Guid.Empty;
            }
            if (Guid.TryParse(stringValue, out var guid))
            {
                return guid;
            }
            // Deterministically hash non-GUID string into a valid Guid
            var hash = MD5.HashData(Encoding.UTF8.GetBytes(stringValue));
            return new Guid(hash);
        }
        return reader.GetGuid();
    }

    public override void Write(Utf8JsonWriter writer, Guid value, JsonSerializerOptions options)
    {
        writer.WriteStringValue(value.ToString());
    }
}
