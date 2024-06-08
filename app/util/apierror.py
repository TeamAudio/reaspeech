from fastapi.responses import JSONResponse

class APIError(Exception):
    def __init__(self, error):
        self.error = error

    def to_response(self):
        return error_response(self.error)

def error_dict(error):
    return {"error": str(error)}

def error_response(error):
    return JSONResponse(status_code=500, content=error_dict(error))
