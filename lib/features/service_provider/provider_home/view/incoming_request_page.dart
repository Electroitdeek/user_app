import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_home/bloc/provider_dashboard_bloc/provider_dashboard_event.dart';
import 'package:adhisaat_health_care/features/service_provider/provider_home/bloc/provider_dashboard_bloc/provider_dashboard_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../bloc/provider_dashboard_bloc/provider_dashboard_bloc.dart';

class IncomingRequestPage extends StatelessWidget {
  const IncomingRequestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<ProviderDashboardBloc, ProviderDashboardState>(
          builder: (context, state) {
            if (state is! NewRequestReceived) return SizedBox();

            final req = state.request;

            return Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: LatLng(req.latitude, req.longitude), zoom: 15),
                  markers: {Marker(markerId: MarkerId("patient"), position: LatLng(req.latitude, req.longitude))},
                  myLocationEnabled: true,
                ),

                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(req.patientName, style: kTextSemiBold2()),
                        SizedBox(height: 4),
                        Text(req.serviceType, style: kTextNormal()),
                        SizedBox(height: 16),
                        RequestActionButtons(state: state),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class RequestActionButtons extends StatelessWidget {
  final NewRequestReceived state;

  const RequestActionButtons({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              context.read<ProviderDashboardBloc>().add(
                AcceptRequestEvent(requestId: state.request.id, request: state.request),
              );
            },
            child: Text("ACCEPT"),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<ProviderDashboardBloc>().add(RejectRequestEvent(requestId: state.request.id));
              Navigator.pop(context);
            },
            child: Text("REJECT"),
          ),
        ),
      ],
    );
  }
}
