using NameApp.Services;
using Amazon.DynamoDBv2;
using Amazon;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllersWithViews();

// Configure AWS DynamoDB client with proper region and credentials
builder.Services.AddScoped<IAmazonDynamoDB>(provider =>
{
    var configuration = provider.GetRequiredService<IConfiguration>();
    var region = configuration["AWS:Region"] ?? "eu-west-1";
    
    var config = new AmazonDynamoDBConfig
    {
        RegionEndpoint = RegionEndpoint.GetBySystemName(region)
    };
    
    return new AmazonDynamoDBClient(config);
});

builder.Services.AddScoped<INameService, DynamoDbNameService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();

app.UseAuthorization();

app.MapStaticAssets();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}")
    .WithStaticAssets();


app.Run();
