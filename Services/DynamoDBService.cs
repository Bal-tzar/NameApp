using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.DocumentModel;
using Amazon.DynamoDBv2.Model;
using NameApp.Models;
using System.Text.Json;

namespace NameApp.Services
{
    public class DynamoDbNameService : INameService
    {
        private readonly IAmazonDynamoDB _dynamoDbClient;
        private readonly string _tableName;

        public DynamoDbNameService(IAmazonDynamoDB dynamoDbClient, IConfiguration configuration)
        {
            _dynamoDbClient = dynamoDbClient;
            _tableName = configuration["DynamoDB:TableName"] ?? "Names";
        }

        public async Task<IEnumerable<Name>> GetAllNamesAsync()
        {
            try
            {
                var scanRequest = new ScanRequest
                {
                    TableName = _tableName
                };

                var response = await _dynamoDbClient.ScanAsync(scanRequest);
                var names = new List<Name>();

                foreach (var item in response.Items)
                {
                    if (!item.ContainsKey("Id") || !item.ContainsKey("FullName") || !item.ContainsKey("DateAdded"))
                        continue;

                    var name = new Name
                    {
                        Id = item["Id"].S,
                        FullName = item["FullName"].S,
                        DateAdded = DateTime.TryParse(item["DateAdded"].S, out var dateAdded) 
                            ? dateAdded 
                            : DateTime.UtcNow
                    };
                    names.Add(name);
                }

                return names.OrderByDescending(n => n.DateAdded);
            }
            catch (Exception ex)
            {
                // Log the exception (implement logging as needed)
                throw new Exception($"Error retrieving names from DynamoDB: {ex.Message}", ex);
            }
        }

        public async Task<Name?> GetNameByIdAsync(string id)
        {
            try
            {
                var request = new GetItemRequest
                {
                    TableName = _tableName,
                    Key = new Dictionary<string, AttributeValue>
                    {
                        { "Id", new AttributeValue { S = id } }
                    }
                };

                var response = await _dynamoDbClient.GetItemAsync(request);

                if (response.Item == null || !response.Item.Any())
                    return null;

                if (!response.Item.ContainsKey("Id") || !response.Item.ContainsKey("FullName") || !response.Item.ContainsKey("DateAdded"))
                    return null;

                return new Name
                {
                    Id = response.Item["Id"].S,
                    FullName = response.Item["FullName"].S,
                    DateAdded = DateTime.TryParse(response.Item["DateAdded"].S, out var dateAdded) 
                        ? dateAdded 
                        : DateTime.UtcNow
                };
            }
            catch (Exception ex)
            {
                throw new Exception($"Error retrieving name by ID from DynamoDB: {ex.Message}", ex);
            }
        }

        public async Task AddNameAsync(Name name)
        {
            try
            {
                var item = new Dictionary<string, AttributeValue>
                {
                    { "Id", new AttributeValue { S = name.Id } },
                    { "FullName", new AttributeValue { S = name.FullName } },
                    { "DateAdded", new AttributeValue { S = name.DateAdded.ToString("O") } } // ISO 8601 format
                };

                var request = new PutItemRequest
                {
                    TableName = _tableName,
                    Item = item
                };

                await _dynamoDbClient.PutItemAsync(request);
            }
            catch (Exception ex)
            {
                throw new Exception($"Error adding name to DynamoDB: {ex.Message}", ex);
            }
        }

        public async Task DeleteNameAsync(string id)
        {
            try
            {
                var request = new DeleteItemRequest
                {
                    TableName = _tableName,
                    Key = new Dictionary<string, AttributeValue>
                    {
                        { "Id", new AttributeValue { S = id } }
                    }
                };

                await _dynamoDbClient.DeleteItemAsync(request);
            }
            catch (Exception ex)
            {
                throw new Exception($"Error deleting name from DynamoDB: {ex.Message}", ex);
            }
        }
    }
}