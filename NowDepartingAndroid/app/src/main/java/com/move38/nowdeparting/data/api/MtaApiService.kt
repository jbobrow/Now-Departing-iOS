package com.move38.nowdeparting.data.api

import com.move38.nowdeparting.data.model.NearbyApiResponse
import com.move38.nowdeparting.data.model.RouteApiResponse
import retrofit2.http.GET
import retrofit2.http.Path
import retrofit2.http.Query

interface MtaApiService {
    companion object {
        const val BASE_URL = "https://api.wheresthefuckingtrain.com/"
    }

    @GET("by-route/{routeId}")
    suspend fun getTrainsByRoute(@Path("routeId") routeId: String): RouteApiResponse

    @GET("by-location")
    suspend fun getTrainsByLocation(
        @Query("lat") latitude: Double,
        @Query("lon") longitude: Double
    ): NearbyApiResponse
}
