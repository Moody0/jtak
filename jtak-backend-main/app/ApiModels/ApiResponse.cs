namespace App.ApiModels
{
    /// <summary>
    /// 
    /// </summary>
    /// <typeparam name="T"></typeparam>
    //public class ApiResponse<T>
    //{
    //    /// <summary>
    //    /// Create Response Object
    //    /// </summary>
    //    /// <param name="data"></param>
    //    /// <returns></returns>
    //    public static ApiResponse<T> Create(T data)
    //    {
    //        return new ApiResponse<T> { Data = data };
    //    }

    //    /// <summary>
    //    /// Create Failure object with list of error messages
    //    /// </summary>
    //    /// <param name="msgs"></param>
    //    /// <returns>ApiResponse&lt;T&gt;</returns>
    //    public static ApiResponse<T> CreateFailure(params string[] msgs) => new ApiResponse<T> { Errors = msgs };

    //    /// <summary>
    //    /// Create Failure object with list of error messages
    //    /// </summary>
    //    /// <param name="msgs"></param>
    //    /// <returns>ApiResponse&lt;T&gt;</returns>
    //    public static ApiResponse<T> CreateFailure(IEnumerable<string> msgs) => CreateFailure(msgs.ToArray());

    //    /// <summary>
    //    /// Create Failure object with list of error messages
    //    /// </summary>
    //    /// <param name="result">IdentityResult with errors</param>
    //    /// <returns>ApiResponse&lt;T&gt;</returns>
    //    public static ApiResponse<T> CreateFailure(IdentityResult result)
    //    {
    //        var errors = result.Errors.Select(x => x.Code + ":" + x.Description);
    //        return CreateFailure(errors);
    //    }


    //    public static ApiResponse<T> CreateFailure(ModelStateDictionary modelState)
    //    {
    //        var errors = modelState.Values.SelectMany(x => x.Errors).Select(x => x.ErrorMessage);
    //        return CreateFailure(errors);
    //    }

    //    public static ApiResponse<T> CreateFailure(Exception ex)
    //    {
    //        var errors = ex.Message;
    //        return CreateFailure(errors);
    //    }
    //    /// <summary>
    //    /// Data response.
    //    /// </summary>
    //    public T Data { get; set; }
    //    /// <summary>
    //    /// Check if an exception occurred.
    //    /// </summary>
    //    public bool Success => !Errors.Any();
    //    /// <summary>
    //    /// Return list of errors if exists.
    //    /// </summary>
    //    public string[] Errors { get; set; } = new string[] { };
    //    /// <summary>
    //    /// Request Id
    //    /// </summary>
    //    public string RequestId = Guid.NewGuid().ToString("D");
    //    /// <summary>
    //    /// Response TimeStamp
    //    /// </summary>
    //    public DateTime TimeStamp = DateTime.UtcNow;

    //    public override string ToString() => JsonSerializer.Serialize(this);

    //}
}