FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY ["src/Tron.Api/Tron.Api.csproj", "src/Tron.Api/"]
RUN dotnet restore "src/Tron.Api/Tron.Api.csproj"

COPY src/ src/
COPY trondb.sql ./trondb.sql
RUN dotnet publish "src/Tron.Api/Tron.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
COPY --from=build /src/trondb.sql ./trondb.sql

RUN mkdir -p /var/tron/media
ENV ASPNETCORE_URLS=http://+:5080
ENV Storage__MediaRoot=/var/tron/media
EXPOSE 5080

ENTRYPOINT ["dotnet", "Tron.Api.dll"]
